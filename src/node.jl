## Defining infos here
@hl mutable struct ChildrenGenerationInfo end
@hl mutable struct BranchingEvaluationInfo end
@hl mutable struct EvalInfo end
@hl mutable struct SetupInfo end


@hl mutable struct Node
    params::Params
    children::Vector{Node}
    depth::Int
    prune_dat_treat_node_start::Bool
    estimated_sub_tree_size::Int
    sub_tree_size::Int

    node_inc_lp_dual_bound::Float
    node_inc_ip_dual_bound::Float
    node_inc_lp_primal_bound::Float
    node_inc_ip_primal_bound::Float

    sub_tree_dual_bound::Float

    dual_bound_is_updated::Bool
    ip_primal_bound_is_updated::Bool

    node_inc_ip_primal_sol::PrimalSolution
    local_fixed_solution::PrimalSolution

    eval_end_time::Int
    treat_order::Int

    infeasible::Bool
    evaluated::Bool
    treated::Bool

    ### New information recorded when the node was generated
    local_branching_constraints::Vector{BranchConstr}

    ### Information recorded by father
    problem_setup_info::SetupInfo
    eval_info::EvalInfo
    children_generation_info::ChildrenGenerationInfo
    branching_eval_info::BranchingEvaluationInfo #for branching history

    problem_and_eval_alg_info_saved::Bool
    primal_sol::PrimalSolution # More information than only ::PrimalSolution
    strong_branch_phase_number::Int
    strong_branch_node_number::Int

end

function NodeBuilder(problem::ExtendedProblem, dual_bound::Float,
    problem_setup_info::SetupInfo, eval_info::EvalInfo)

    return (
        problem.params,
        Node[],
        0,
        false,
        typemax(Int),
        -1,
        dual_bound,
        dual_bound,
        problem.primal_inc_bound,
        problem.primal_inc_bound,
        dual_bound,
        false,
        false,
        PrimalSolution(),
        PrimalSolution(),
        -1,
        -1,
        false,
        false,
        false,
        BranchConstr[],
        problem_setup_info,
        eval_info,
        ChildrenGenerationInfo(),
        BranchingEvaluationInfo(),
        false,
        PrimalSolution(),
        0,
        -1
    )
end

@hl mutable struct NodeWithParent <: Node
    parent::Node
end

function NodeWithParentBuilder(problem::ExtendedProblem, parent::Node)

    return tuplejoin(NodeBuilder(problem, parent.node_inc_ip_dual_bound,
        parent.problem_setup_info, parent.eval_info),
        parent
    )

end

function is_conquered(node::Node)
    return (node.node_inc_ip_primal_bound - node.node_inc_ip_dual_bound
            <= node.params.mip_tolerance_integrality)
end

function is_to_be_pruned(node::Node, global_primal_bound::Float)
    return (global_primal_bound - node.node_inc_ip_dual_bound
        <= node.params.mip_tolerance_integrality)
end

function set_branch_and_price_order(node::Node, new_value::Int)
    node.treat_order = new_value
end

function exit_treatment(node::Node)
    # Issam: No need for deleting. I prefer deleting the node and storing the info
    # needed for printing the tree in a different light structure (for now)
    # later we can use Nullable for big data such as XXXInfo of node

    node.evaluated = true
    node.treated = true
end

function mark_infeasible_and_exit_treatment(node::Node)
    node.infeasible = true
    node.node_inc_lp_dual_bound = node.node_inc_ip_dual_bound = Inf
    exit_treatment(node)
end

function record_ip_primal_sol_and_update_ip_primal_bound(node::Node,
        sols_and_bounds)

    if node.node_inc_ip_primal_bound > sols_and_bounds.alg_inc_ip_primal_bound
        sol = PrimalSolution(sols_and_bounds.alg_inc_ip_primal_bound,
                             sols_and_bounds.alg_inc_ip_primal_sol_map)
        node.node_inc_ip_primal_sol = sol
        node.node_inc_ip_primal_bound = sols_and_bounds.alg_inc_ip_primal_bound
        node.ip_primal_bound_is_updated = true
    end
end

function save_problem_and_eval_alg_info(node::Node)
end

function store_branching_evaluation_info()
end

function update_node_duals(node::Node, sols_and_bounds)
    lp_dual_bound = sols_and_bounds.alg_inc_lp_dual_bound
    ip_dual_bound = sols_and_bounds.alg_inc_ip_dual_bound
    if node.node_inc_lp_dual_bound < lp_dual_bound
        node.node_inc_lp_dual_bound = lp_dual_bound
        node.dual_bound_is_updated = true
    end
    if node.node_inc_ip_dual_bound < ip_dual_bound
        node.node_inc_ip_dual_bound = ip_dual_bound
        node.dual_bound_is_updated = true
    end
end

function update_node_primals(node::Node, sols_and_bounds)
    # sols_and_bounds = node.alg_eval_node.sols_and_bounds
    if sols_and_bounds.is_alg_inc_ip_primal_bound_updated
        record_ip_primal_sol_and_update_ip_primal_bound(node,
            sols_and_bounds)
    end
    node.node_inc_lp_primal_bound = sols_and_bounds.alg_inc_lp_primal_bound
    node.primal_sol = PrimalSolution(node.node_inc_lp_primal_bound,
        sols_and_bounds.alg_inc_lp_primal_sol_map)
end

function update_node_incumbents(node::Node, sols_and_bounds)
    update_node_primals(node, sols_and_bounds)
    update_node_duals(node, sols_and_bounds)
end


@hl mutable struct AlgLike end
run(alg::AlgLike; args...) = false
mutable struct TreatAlgs
    alg_setup_node::AlgLike
    alg_preprocess_node::AlgLike
    alg_eval_node::AlgLike
    alg_setdown_node::AlgLike
    alg_vect_primal_heur_node::Vector{AlgLike}
    alg_generate_children_nodes::AlgLike
    TreatAlgs() = new(AlgLike(), AlgLike(), AlgLike(), AlgLike(), AlgLike[], AlgLike())
end

function evaluation(node::Node, treat_algs::TreatAlgs, global_treat_order::Int,
                    inc_primal_bound::Float)::Bool
    node.treat_order = global_treat_order
    node.node_inc_ip_primal_bound = inc_primal_bound
    node.ip_primal_bound_is_updated = false
    node.dual_bound_is_updated = false
    
    if run(treat_algs.alg_setup_node, node)
        run(treat_algs.alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end

    if run(treat_algs.alg_preprocess_node)
        run(treat_algs.alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end

    @logmsg LogLevel(-3) string("active branching constraints: ")
    for constr in treat_algs.alg_setup_node.extended_problem.master_problem.constr_manager.active_dynamic_list
        @logmsg LogLevel(-3) string("constraint ", constr.vc_ref, ": ")
        for var in keys(constr.member_coef_map)
            @logmsg LogLevel(-3) string(" + ", var.name)
        end
        @logmsg LogLevel(-3) string(" = ", constr.cost_rhs)
    end
    
    if setup(treat_algs.alg_eval_node)  
        setdown(treat_algs.alg_eval_node)
        run(treat_algs.alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end

    if run(treat_algs.alg_eval_node)
        run(treat_algs.alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end
    node.evaluated = true

    #the following should be also called after the heuristics.
    update_node_incumbents(node, treat_algs.alg_eval_node.sols_and_bounds)

    if is_conquered(node)
        println("Node is conquered, no need for branching.")
        setdown(treat_algs.alg_eval_node)
        run(treat_algs.alg_setdown_node)
        store_branching_evaluation_info()
        exit_treatment(node); return true
    elseif false # _evalAlgPtr->subProbSolutionsEnumeratedToMIP() && runEnumeratedMIP()
        setdown(treat_algs.alg_eval_node)
        run(treat_algs.alg_setdown_node)
        store_branching_evaluation_info()
        mark_infeasible_and_exit_treatment(); return true
    end

    if !node.problem_and_eval_alg_info_saved
        save_problem_and_eval_alg_info(node)
    end

    setdown(treat_algs.alg_eval_node)
    run(treat_algs.alg_setdown_node, node)
    store_branching_evaluation_info()
    return true
end

function treat(node::Node, treat_algs::TreatAlgs,
        global_treat_order::Int, inc_primal_bound::Float)::Bool
    # In strong branching, part 1 of treat (setup, preprocessing and solve) is
    # separated from part 2 (heuristics and children generation).
    # Therefore, treat() can be called two times. One inside strong branching,
    # and the second inside the branch-and-price tree. Thus, variables _solved
    # is used to know whether part 1 has already been done or not.

    if !node.evaluated
        if !evaluation(node, treat_algs, global_treat_order, inc_primal_bound)
            return false
        end
    else
        if inc_primal_bound <= node.node_inc_ip_primal_bound ## is it necessary?
            println("should not enter here.")
            node.node_inc_ip_primal_bound = inc_primal_bound
            node.ip_primal_bound_is_updated = false
        end
    end

    if node.treated
        return true
    end

    for alg in treat_algs.alg_vect_primal_heur_node
        run(alg, node, global_treat_order)
        # TODO remove node bound updates from inside heuristics and put it here.
        if node.is_conquered
            exit_treatment(node); return true
        end
    end

    # the generation child nodes algorithm fills the sons
    if setup(treat_algs.alg_generate_children_nodes)
        setdown(treat_algs.alg_generate_children_nodes)
        exit_treatment(node); return true
    end
    run(treat_algs.alg_generate_children_nodes, global_treat_order, node)
    setdown(treat_algs.alg_generate_children_nodes)

    exit_treatment(node); return true
end

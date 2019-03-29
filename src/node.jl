abstract type SetupInfo end

mutable struct TreatOrder
    value::Int
end

mutable struct Node
    parent::Union{Nothing, Node}
    params::Params
    children::Vector{Node}
    depth::Int
    # prune_dat_treat_node_start::Bool
    # estimated_sub_tree_size::Int
    # sub_tree_size::Int

    node_inc_lp_dual_bound::Float64
    node_inc_ip_dual_bound::Float64
    node_inc_lp_primal_bound::Float64
    node_inc_ip_primal_bound::Float64

    dual_bound_is_updated::Bool
    ip_primal_bound_is_updated::Bool

    node_inc_ip_primal_sol::PrimalSolution
    # partial_solution::PrimalSolution

    # eval_end_time::Int
    treat_order::TreatOrder

    infeasible::Bool
    evaluated::Bool
    treated::Bool

    ### New information recorded when the node was generated
    local_branching_constraints::Vector{Constraint}

    ### Information recorded by father
    problem_setup_info::SetupInfo
    # eval_info::EvalInfo
    # children_generation_info::ChildrenGenerationInfo
    # branching_eval_info::BranchingEvaluationInfo #for branching history

    # problem_and_eval_alg_info_saved::Bool
    primal_sol::PrimalSolution # More information than only ::PrimalSolution
    # strong_branch_phase_number::Int
    # strong_branch_node_number::Int

end

function Node(problem::Reformulation, dual_bound::Float64,
    problem_setup_info::SetupInfo, params::Params)
    return Node(
        nothing,
        params,
        Node[],
        0,
        dual_bound,
        dual_bound,
        Inf, #problem.primal_inc_bound,
        Inf, #problem.primal_inc_bound,
        false,
        false,
        PrimalSolution(),
        TreatOrder(-1),
        false,
        false,
        false,
        Constraint[], #MasterBranchConstr[],
        problem_setup_info,
        PrimalSolution(),
    )
end


function NodeWithParentBuilder(problem::Reformulation, parent::Node)

    return tuplejoin(NodeBuilder(problem, parent.node_inc_ip_dual_bound,
        parent.problem_setup_info),
        parent
    )

end

function get_priority(node::Node)
    if node.params.search_strategy == DepthFirst
        return node.depth
    elseif node.params.search_strategy == BestDualBound
        return node.node_inc_lp_dual_bound
    end
end

function is_conquered(node::Node)
    return (node.node_inc_ip_primal_bound - node.node_inc_ip_dual_bound
            <= node.params.mip_tolerance_integrality)
end

function is_to_be_pruned(node::Node, global_primal_bound::Float64)
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

function update_node_primal_inc(node::Node, ip_bound::Float64,
                                sol_map::Dict{Variable, Float64})
    if ip_bound < node.node_inc_ip_primal_sol.cost
        new_sol = PrimalSolution(ip_bound, sol_map)
        node.node_inc_ip_primal_sol = new_sol
        node.node_inc_ip_primal_bound = ip_bound
        node.ip_primal_bound_is_updated = true
        if ip_bound < node.node_inc_lp_primal_bound
            node.node_inc_lp_primal_bound = ip_bound
            node.primal_sol = new_sol
        end
    end
end

function update_node_sols(node::Node, sols_and_bounds)
    update_node_primals(node, sols_and_bounds)
    update_node_duals(node, sols_and_bounds)
end


@hl mutable struct AlgLike end

function run(::AlgLike)
    @logmsg LogLevel(0) "Empty algorithm"
    return false
end

function to(alg::AlgLike; args...)
    return alg.extended_problem.timer_output
end

mutable struct TreatAlgs
    alg_setup_node::AlgLike
    alg_preprocess_node::AlgLike
    alg_eval_node::AlgLike
    alg_setdown_node::AlgLike
    alg_vect_primal_heur_node::Vector{AlgLike}
    alg_generate_children_nodes::AlgLike
    TreatAlgs() = new(AlgLike(), AlgLike(), AlgLike(), AlgLike(), AlgLike[], AlgLike())
end

struct TreatAlgsTwo{St <: AbstractSetupNodeAlg,
                    Gc <: AbstractGenChildrenNodeAlg,
                    Ri <: AbstractRecordInfoNodeAlg
                    }
    # Obligatory algorithms
    setup::St
    gen_children::Gc
    record_info::Ri
    # Facultative algorithms
    algs::Vector{<:AbstractNodeAlg}
    nb_completed_facultative_algs::Int
    did_setup::Bool
    did_gen_children::Bool
    info_is_recorded::Bool
end
function should_interrupt_treat(treat_algs::TreatAlgsTwo, node::Node)
    return false
end
function interrupt_treat(treat_algs::TreatAlgsTwo, node::Node)
    return false
end

function treat_two(node, treat_algs)
    # do setup

    for alg in treat_algs.algs
        setup(alg, node, treat_algs) # checks if needs to record info and do setup
        run(alg)
        setdown(alg, node, treat_algs) # record node info if needed
    end

    # gen children
end

function evaluation(node::Node, treat_algs::TreatAlgs,
                    global_treat_order::TreatOrder,
                    inc_primal_bound::Float64)::Bool
    node.treat_order = TreatOrder(global_treat_order.value)
    node.node_inc_ip_primal_bound = inc_primal_bound
    node.ip_primal_bound_is_updated = false
    node.dual_bound_is_updated = false

    run(treat_algs.alg_setup_node)

    if run(treat_algs.alg_preprocess_node)
        @logmsg LogLevel(0) string("Preprocess determines infeasibility.")
        run(treat_algs.alg_setdown_node)
        record_node_info(node, treat_algs.alg_setdown_node)
        mark_infeasible_and_exit_treatment(node)
        return true
    end

    if run(treat_algs.alg_eval_node, inc_primal_bound)
        update_node_sols(node, treat_algs.alg_eval_node.sols_and_bounds)
        run(treat_algs.alg_setdown_node)
        record_node_info(node, treat_algs.alg_setdown_node)
        mark_infeasible_and_exit_treatment(node)
        return true
    end
    node.evaluated = true

    update_node_sols(node, treat_algs.alg_eval_node.sols_and_bounds)

    if is_conquered(node)
        @logmsg LogLevel(-2) string("Node is conquered, no need for branching.")
        run(treat_algs.alg_setdown_node)
        record_node_info(node, treat_algs.alg_setdown_node)
        exit_treatment(node);
        return true
    end

    run(treat_algs.alg_setdown_node)
    record_node_info(node, treat_algs.alg_setdown_node)

    return true
end

function treat(node::Node, treat_algs::TreatAlgs,
        global_treat_order::TreatOrder, inc_primal_bound::Float64)::Bool
    # In strong branching, part 1 of treat (setup, preprocessing and solve) is
    # separated from part 2 (heuristics and children generation).
    # Therefore, treat() can be called two times. One inside strong branching,
    # and the second inside the branch-and-price tree. Thus, variables _solved
    # is used to know whether part 1 has already been done or not.

    if !node.evaluated
        evaluation(node, treat_algs, global_treat_order, inc_primal_bound)
    end

    if node.treated
        @logmsg LogLevel(0) "Node is considered as treated after evaluation"
        return true
    end

    for alg in treat_algs.alg_vect_primal_heur_node
        run(alg, global_treat_order)
        update_node_primal_inc(node, alg.sols_and_bounds.alg_inc_ip_primal_bound,
                               alg.sols_and_bounds.alg_inc_ip_primal_sol_map)
        println("<", typeof(alg), ">", " <mlp=",
                node.node_inc_lp_primal_bound, "> ",
                "<PB=", node.node_inc_ip_primal_bound, ">")
        if is_conquered(node)
            @logmsg LogLevel(0) string("Node is considered conquered ",
                                       "after primal heuristic ", typeof(alg))
            exit_treatment(node)
            return true
        end
    end

    if !run(treat_algs.alg_generate_children_nodes, node.primal_sol)
        generate_children(node, treat_algs.alg_generate_children_nodes)
    end

    exit_treatment(node)

    return true
end

function prepare_node_for_treatment(extended_problem::Reformulation,
        node::Node, treat_algs::TreatAlgs,
        global_treat_order::TreatOrder)

    if node.parent == nothing
        println("************************************************************")
        println("Preparing root node for treatment.")

        params = node.params
        treat_algs.alg_setup_node = AlgToSetupRootNode(extended_problem,
            node.problem_setup_info, node.local_branching_constraints)
    else
        println("************************************************************")
        println("Preparing node ", global_treat_order.value,
            " for treatment. Parent is ", node.parent.treat_order.value, ".")
        println("Elapsed time: ", elapsed_solve_time(), " seconds.")
        println("Current primal bound is ", extended_problem.primal_inc_bound)
        println("Subtree dual bound is ", node.node_inc_ip_dual_bound)
        print("Branching constraint:  ")
        coluna_print(node.local_branching_constraints[1])

        params = node.params
        if is_to_be_pruned(node, extended_problem.primal_inc_bound)
            println("Node is conquered, no need for treating it.")
            return false 
        end

        if global_treat_order.value == node.parent.treat_order.value+1
            treat_algs.alg_setup_node = AlgToSetupBranchingOnly(extended_problem,
                node.problem_setup_info, node.local_branching_constraints)
        else
            treat_algs.alg_setup_node = AlgToSetupFull(extended_problem,
                node.problem_setup_info, node.local_branching_constraints)
        end
    end
    if params.apply_preprocessing
        treat_algs.alg_preprocess_node = AlgToPreprocessNode(node.depth, extended_problem)
    end
    treat_algs.alg_setdown_node = AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = UsualBranchingAlg(node.depth,
                                                            extended_problem)

    if !node.evaluated
        treat_algs.alg_eval_node = select_eval_alg(extended_problem,
                                                params.node_eval_mode)
    end

    if params.use_restricted_master_heur
        push!(treat_algs.alg_vect_primal_heur_node,
            AlgToPrimalHeurByRestrictedMip(
                extended_problem,
                params.restricted_master_heur_solver_type)
            )
    end

    return true
end

function print_info_before_solving_node(problem::Reformulation,
        primal_tree_nb_open_nodes::Int, sec_tree_nb_open_nodes::Int,
        treat_order::TreatOrder)

    print(primal_tree_nb_open_nodes)
    println(" open nodes. Treating node ", treat_order.value, ".")
    println("Current best known bounds : [ ", problem.dual_inc_bound,  " , ",
        problem.primal_inc_bound, " ]")
    println("************************************************************")
    return
end

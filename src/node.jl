@hl type Node
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

    node_inc_ip_primal_sol::Solution
    local_fixed_solution::Solution

    eval_end_time::Int
    treat_order::Int

    infeasible::Bool
    evaluated::Bool
    treated::Bool

    problem_setup_info::ProblemSetupInfo
    eval_info::EvalInfo
    children_generation_info::ChildrenGenerationInfo
    branching_eval_info::BranchingEvaluationInfo #for branching history

    problem_and_eval_alg_info_saved::Bool
    solution_var_info_list::Solution # More information than only ::Solution
    strong_branch_phase_number::Int
    strong_branch_node_number::Int

    alg_setup_node::AlgToSetupNode
    alg_preprocess_node::AlgToPreprocessNode
    alg_eval_node::AlgToEvalNode
    alg_setdown_node::AlgToSetdownNode
    alg_vect_primal_heur_node::Vector{AlgToPrimalHeurInNode}
    alg_generate_children_nodes::AlgToGenerateChildrenNodes
end

function NodeBuilder(model, dual_bound::Float,
    problem_setup_info::ProblemSetupInfo, eval_info::EvalInfo,
    alg_setup_node::AlgToSetupNode,
    alg_preprocess_node::AlgToPreprocessNode,
    alg_eval_node::AlgToEvalNode,
    alg_setdown_node::AlgToSetdownNode,
    alg_vect_primal_heur_node::Vector{AlgToPrimalHeurInNode},
    alg_generate_children_nodes::AlgToGenerateChildrenNodes)

    return (
        model.params,
        Node[],
        0,
        false,
        typemax(Int),
        -1,
        dual_bound,
        dual_bound,
        model.extended_problem.primal_inc_bound,
        model.extended_problem.primal_inc_bound,
        dual_bound,
        false,
        false,
        Solution(),
        Solution(),
        -1,
        -1,
        false,
        false,
        false,
        problem_setup_info,
        eval_info,
        ChildrenGenerationInfo(),
        BranchingEvaluationInfo(),
        false,
        Solution(),
        0,
        -1,
        alg_setup_node,
        alg_preprocess_node,
        alg_eval_node,
        alg_setdown_node,
        alg_vect_primal_heur_node,
        alg_generate_children_nodes
    )
end


function NodeBuilder(model, dual_bound::Float,
    problem_setup_info::ProblemSetupInfo, eval_info::EvalInfo)

    return (
        model.params,
        Node[],
        0,
        false,
        typemax(Int),
        -1,
        dual_bound,
        dual_bound,
        model.extended_problem.primal_inc_bound,
        model.extended_problem.primal_inc_bound,
        dual_bound,
        false,
        false,
        Solution(),
        Solution(),
        -1,
        -1,
        false,
        false,
        false,
        problem_setup_info,
        eval_info,
        ChildrenGenerationInfo(),
        BranchingEvaluationInfo(),
        false,
        Solution(),
        0,
        -1,
        AlgToSetupNode(model.extended_problem),
        AlgToPreprocessNode(),
        AlgToEvalNode(),
        AlgToSetdownNode(model.extended_problem),
        Vector{AlgToPrimalHeurInNode}(),
        AlgToGenerateChildrenNodes()
    )
end

@hl type NodeWithParent <: Node
    parent::Node
end

function NodeWithParentBuilder(model, dual_bound::Float,
    problem_setup_info::ProblemSetupInfo, eval_info::EvalInfo, parent::Node)

    return tuplejoin(NodeBuilder( model, dual_bound,
        problem_setup_info, eval_info, parent.alg_setup_node,
        parent.alg_preprocess_node, parent.alg_eval_node,
        parent.alg_setdown_node, parent.alg_vect_primal_heur_node,
        parent.alg_generate_children_nodes
        ),
        parent
    )

end


function exit_treatment(node::Node)::Void
    # No need for deleting. I prefer deleting the node and storing the info
    # needed for printing the tree in a different light structure (for now)
    # later we can use Nullable for big data such as XXXInfo of node

    node.evaluated = true
    node.treated = true
end

function evaluation(node::Node, global_treat_order::Int,
                    inc_primal_bound::Float)::Bool
    node.treat_order = global_treat_order
    node.node_inc_ip_primal_bound = inc_primal_bound
    node.ip_primal_bound_is_updated = false
    node.dual_bound_is_updated = false

    if run(alg_setup_node, node)
        run(alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end

    if run(alg_preprocess_node, node)
        run(alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end

    if setup(alg_eval_node, node)
        setdown(alg_eval_node)
        run(alg_setdown_node)
        mark_infeasible_and_exit_treatment(node); return true
    end
    node.evaluated = true

    #the following should be also called after the heuristics.
    if alg_eval_node.is_alg_inc_ip_primal_bound_updated
        record_ip_primal_sol_and_update_ip_primal_bound(alg_eval_node)
    end

    node_inc_lp_primal_bound = alg_eval_node.alg_inc_lp_primal_bound
    update_node_dual_bounds(node, alg_eval_node.alg_inc_lp_dual_bound,
                         alg_eval_node.alg_inc_ip_dual_bound)

    if is_conquered(node)
        setdown(alg_eval_node)
        run(alg_setdown_node)
        store_branching_evaluation_info()
        exit_treatment(node); return true
    elseif false # _evalAlgPtr->subProbSolutionsEnumeratedToMIP() && runEnumeratedMIP()
        setdown(alg_eval_node)
        run(alg_setdown_node)
        store_branching_evaluation_info()
        mark_infeasible_and_exit_treatment(); return true
    end

    if !node.problem_and_eval_alg_info_saved
        save_problem_and_eval_alg_info(node)
    end

    setdown(alg_eval_node)
    run(alg_setdown_node)
    store_branching_evaluation_info()
    return true;
end

function treat(node::Node, global_treat_order::Int, inc_primal_bound::Float)::Bool
    # In strong branching, part I of treat (setup, preprocessing and solve) is
    # separated from part II (heuristics and children generation).
    # Therefore, treat() can be called two times, one inside strong branching,
    # second inside the branch-and-price tree. Thus, variables _solved
    # is used to know whether part I has already been done or not.

    if !node.evaluated
        if !evaluation(node, global_treat_order, inc_primal_bound)
            return false
        end
    else
        if inc_primal_bound <= node_inc_ip_primal_bound
            node_inc_ip_primal_bound = inc_primal_bound
            ip_primal_bound_is_updated = false
        end
    end

    if treated
        return true
    end

    for alg in node.alg_vect_primal_heur_node
        run(alg, node, global_treat_order)
        # TODO put node bound updates from inside heuristics and put it here.
        if is_conquered(node)
            exit_treatment(node); return true
        end
    end

    # the generation child nodes algorithm fills the sons
    if setup(node.alg_generate_children_nodes, node)
        setdown(node.alg_generate_children_nodes)
        exit_treatment(node); return true
    end

    run(node.alg_generate_children_nodes, global_treat_order)
    setdown(node.alg_generate_children_nodes)

    exit_treatment(node); return true
end

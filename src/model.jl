@enum(SEARCHSTRATEGY,BestDualBoundThanDF,DepthFirstWithWorseBound,
BestLpBound, DepthFirstWithBetterBound)


@hl type Callback end

type Model # user model
    extended_problem::ExtendedProblem
    callback::Callback
    params::Params
end

function ModelConstructor(extended_problem::ExtendedProblem,
        callback::Callback, params::Params)
    return Model(extended_problem, callback, params)
end

function create_root_node(model::Model)::Node
    params = model.params
    problem_setup_info = ProblemSetupInfo(0)
    stab_info  = StabilizationInfo(model.extended_problem.master_problem, params)
    master_lp_basis = LpBasisRecord("Basis0")

    # node_eval_info = ColGenEvalInfo(stab_info, master_lp_basis, Inf)
    node_eval_info = LpEvalInfo(stab_info)

    return Node(model, model.extended_problem.dual_inc_bound,
        problem_setup_info, node_eval_info)
end

### For root node
function prepare_node_for_treatment(model::Model, node::Node,
        global_nodes_treat_order::Int, nb_treated_nodes::Int)::Bool

    # node.alg_setup_node = AlgToSetupNode()
    # node.alg_generate_children_nodes = AlgToGenerateChildrenNodes()
    #
    # node.alg_vect_primal_heur_node = AlgToPrimalHeurInNode[]
    #
    # node.alg_setdown_node = AlgToSetdownNode()

    @show node.evaluated
    if !node.evaluated
        ## Dispatched according to eval_info
        node.alg_eval_node = AlgToEvalNodeByLp(node.eval_info)
        println("here")
    end

    return true
end

function prepare_node_for_treatment(model::Model, node::NodeWithParent,
        global_nodes_treat_order::Int, nb_treated_nodes::Int)::Bool

    # node.alg_setup_node = AlgToSetupNode()
    #
    # ## Change depending on solving method
    # node.alg_eval_node = AlgToEvalNode()
    #
    # node.alg_generate_children_nodes = AlgToGenerateChildrenNodes()
    #
    # node.alg_vect_primal_heur_node = AlgToPrimalHeurInNode[]
    #
    # node.alg_setdown_node = AlgToSetdownNode()

end

function solve(model::Model)
    search_tree = DS.Queue(Node)
    params = model.params
    global_nodes_treat_order = 0
    nb_treated_nodes = 0
    cur_node = create_root_node(model)
    DS.enqueue!(search_tree, cur_node)
    bap_treat_order = 1 # Only usefull for printing

    while (!isempty(search_tree) && nb_treated_nodes < params.max_num_nodes)

        cur_node_evaluated_before = cur_node.evaluated

        if prepare_node_for_treatment(model, cur_node, global_nodes_treat_order,
            nb_treated_nodes)

            print_info_before_solving_node(search_tree.size() +
                ((is_primary_tree_node) ? 1 : 0),
                ((is_primary_tree_node) ? 0 : 1))

            if !cur_node_evaluated_before
                branch_and_price_order(cur_node, bap_treat_order)
                bap_treat_order += 1
                nice_print(cur_node, true)
            end

            if !treat(cur_node, global_nodes_treat_order, primal_inc_bound)
                println("error: branch-and-price is interrupted")
                break
            end

            # the output of the treated node are the generated child nodes and
            # possibly the updated bounds and the
            # updated solution, we should update primal bound before dual one
            # as the dual bound will be limited by the primal one
            if cur_node.primal_bound_is_updated
                update_primal_inc_solution(model, cur_node.node_inc_ip_primal_sol)
            end

            if cur_node.dual_bound_is_updated
                update_cur_valid_dual_bound(model, cur_node)
            end

            ## Put this in a function 'update_tree_with_children'
            for child_node in cur_node.children
                push!(bap_tree_nodes, child_node)
                if child_node.dual_bound_is_updated
                    update_cur_valid_dual_bound(model, child_node)
                end
                if length(search_tree) < params.open_nodes_limit
                    enqueue(search_tree, child_node)
                else
                    print("Limit on the number of open nodes is reached.")
                    println("No secondary tree is implemented.")
                    # enqueue(secondary_search_tree, child_node)
                end
            end
        end

        if isempty(cur_node.children)
            calculate_subtree_size(cur_node, model.sub_tree_size_by_depth)
        end
    end
end

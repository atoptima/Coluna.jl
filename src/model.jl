@enum(SEARCHSTRATEGY,BestDualBoundThanDF,DepthFirstWithWorseBound,
BestLpBound, DepthFirstWithBetterBound)

type ExtendedProblem <: Problem
    master_problem::CompactProblem # restricted master in DW case.
    pricing_vect::Vector{Problem}
    separation_vect::Vector{Problem}
    params::Params
    counter::VarConstrCounter
    solution::Solution
    primal_inc_bound::Float
    dual_inc_bound::Float
    subtree_size_by_depth::Int
end

# function ExtendedProblemConstructor(master_problem::CompactProblem, )
#
# end

@hl type Callback end

type Model # user model
    extended_problem::ExtendedProblem
    callback::Callback
    params::Params
end

function ModelConstructor()

end

function create_root_node(model::Model)::Node
    params = model.params
    problem_setup_info = ProblemSetupInfo(0)
    stab_info  = StabilizationInfo(model.master_prob, params)
    master_lp_basis = LpBasisRecord("Basis0")
    node_eval_info = ColGenEvalInfo(stab_info, master_lp_basis, Inf)

    return Node(model, model.dual_inc_bound, problem_setup_info, node_eval_info)
end

function solve(model::Model)::Solution
    params = model.params
    global_nodes_treat_order = 0
    this_search_tree_treated_nodes_number = 0
    cur_node = create_root_node(model)
    bap_treat_order = 1 # usefull only for printing only

    this_search_tree_treated_nodes_number += 1
    while (!isempty(search_tree) &&
            this_search_tree_treated_nodes_number <
            params.max_nb_of_bb_tree_node_treated)

        is_primary_tree_node = isempty(secondary_search_tree)
        cur_node_solved_before = is_solved(cur_node)

        if prepare_node_for_treatment(cur_node, global_nodes_treat_order,
             this_search_tree_treated_nodes_number-1)

            print_info_before_solving_node(search_tree.size() +
                ((is_primary_tree_node) ? 1 : 0), secondary_search_tree.size() +
                ((is_primary_tree_node) ? 0 : 1))

            if !cur_node_solved_before
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

            for child_node in cur_node.children
                push!(bap_tree_nodes, child_node)
                if child_node.dual_bound_is_updated
                   update_cur_valid_dual_bound(model, child_node)
                end
                if length(search_tree) < params.opennodeslimit
                   enqueue(search_tree, child_node)
                else
                   enqueue(secondary_search_tree, child_node)
                end
            end
        end

        if isempty(cur_node.children)
            calculate_subtree_size(cur_node, model.sub_tree_size_by_depth);
        end
    end
end

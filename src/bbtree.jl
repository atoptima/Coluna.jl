struct SearchTree
    primary_tree::DS.PriorityQueue{Node, Float64}
    # secondary_tree::DS.PriorityQueue{Node, Float64}
    priority_function::Function
    in_primary::Bool
    treat_order::Int
    nb_treated_nodes::Int
end

function build_priority_function(strategy::SEARCHSTRATEGY)
    strategy == DepthFirst && return x->(-x.depth)
    strategy == BestDualBound && return x->x.node_inc_lp_dual_bound
end

SearchTree(search_strategy::SEARCHSTRATEGY) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward),
    # DS.PriorityQueue{Node, Float64}(Base.Order.Forward),
    build_priority_function(search_strategy),
    true, 0, 0
)

Base.isempty(t::SearchTree) = isempty(t.primary_tree)
add_node(t::SearchTree, node::Node) = DS.enqueue!(
    t.primary_tree, node, t.priority_function(node)
)
pop_node!(t::SearchTree) = DS.dequeue!(t.primary_tree)
nb_open_nodes(t::SearchTree) = length(t.primary_tree)
get_treat_order(t::SearchTree) = t.treat_order

function print_info_before_solving_node(search_tree::SearchTree, problem::Reformulation)
    print(nb_open_nodes(search_tree))
    println(" open nodes. Treating node ", get_treat_order(search_tree), ".")
    println("Current best known bounds : [ ", problem.dual_inc_bound,  " , ",
            problem.primal_inc_bound, " ]")
    println("************************************************************")
    return
end



# function update_search_trees(cur_node::Node,
#                              search_tree::DS.PriorityQueue{Node, Float64},
#                              extended_problem::Reformulation)
#     params = extended_problem.params
#     for child_node in cur_node.children
#         # push!(bap_tree_nodes, child_node)
#         # if child_node.dual_bound_is_updated
#         #     update_cur_valid_dual_bound(model, child_node)
#         # end
#         if length(search_tree) < params.open_nodes_limit
#             DS.enqueue!(search_tree, child_node, get_priority(child_node))
#         else
#             println("Limit on the number of open nodes is reached and",
#                     "no secondary tree is implemented.")
#             # enqueue(secondary_search_tree, child_node)
#         end
#     end
# end

# function update_cur_valid_dual_bound(problem::Reformulation,
#         node::NodeWithParent, search_tree::DS.PriorityQueue{Node, Float64})
#     if isempty(search_tree)
#         problem.dual_inc_bound = problem.primal_inc_bound
#     end
#     worst_dual_bound = Inf
#     for (node,priority) in search_tree
#         if node.node_inc_ip_dual_bound < worst_dual_bound
#             worst_dual_bound = node.node_inc_ip_dual_bound
#         end
#     end
#     if worst_dual_bound != Inf
#         problem.dual_inc_bound = min(worst_dual_bound, problem.primal_inc_bound)
#     end
# end

# function update_cur_valid_dual_bound(problem::Reformulation,
#         node::Node, search_tree::DS.PriorityQueue{Node, Float64})
#     if node.node_inc_ip_dual_bound > problem.dual_inc_bound
#         problem.dual_inc_bound = node.node_inc_ip_dual_bound
#     end
# end

# function update_primal_inc_solution(problem::Reformulation, sol::PrimalSolution)
#     if sol.cost < problem.primal_inc_bound
#         problem.solution = PrimalSolution(sol.cost, sol.var_val_map)
#         problem.primal_inc_bound = sol.cost
#         @logmsg LogLevel(-1) string("New incumbent IP solution with cost: ",
#                                     problem.solution.cost)
#     end
# end

# function update_model_incumbents(problem::Reformulation, node::Node,
#         search_tree::DS.PriorityQueue{Node, Float64})
#     if node.ip_primal_bound_is_updated
#         update_primal_inc_solution(problem, node.node_inc_ip_primal_sol)
#     end
#     if (node.dual_bound_is_updated &&
#                 length(search_tree)
#                 <= problem.params.limit_on_tree_size_to_update_best_dual_bound)
#         update_cur_valid_dual_bound(problem, node, search_tree)
#     end
# end

# function generate_and_write_bap_tree(nodes::Vector{Node})
#     @logmsg LogLevel(-4) "Generation of bap_tree is not yet implemented."
# end

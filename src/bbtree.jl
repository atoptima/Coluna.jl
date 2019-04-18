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

function update_tree(search_tree::SearchTree, cur_node::Node)
    search_tree.treat_order += 1
    search_tree.nb_treated_nodes += 1
    if !to_be_pruned(cur_node)
        add_node(search_tree, cur_node)
    end
    for child_node in cur_node.children
        add_node(search_tree, child_node)
    end
end

function treat_node(n::Node, f::Reformulation, strategy::AbstractStrategy)
# function treat_node(n::Node, f::Reformulation)
    # println("Fake treat node")
    setup_master(n, f.master)
    r = StrategyRecord()
    apply(strategy, f, nothing, r, nothing)
    record_master_info(n, f.master)
end

function search(search_tree::SearchTree, formulation::AbstractFormulation)
    # strategy = formulation.strategy
    add_node(search_tree, RootNode())

    while (!isempty(search_tree)
           && search_tree.nb_treated_nodes < _params_.max_num_nodes)

        cur_node = pop_node!(search_tree)
        print_info_before_solving(cur_node, search_tree, formulation)
        treat_node(cur_node, formulation, strategy)
        print_info_after_solving(cur_node, search_tree, formulation)
        update_formulation(formulation, cur_node)
        update_tree(search_tree, cur_node, formulation)

    end
end

function print_info_before_solving_node(search_tree::SearchTree, problem::AbstractFormulation)
    print(nb_open_nodes(search_tree))
    println(" open nodes. Treating node ", get_treat_order(search_tree), ".")
    println("\e[1;31m TODO : display bounds here \e[00m")
    #println("Current best known bounds : [ ", problem.dual_inc_bound,  " , ",
    #        problem.primal_inc_bound, " ]")
    println("************************************************************")
    return
end

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

# function update_prob_incumbents(problem::Reformulation, node::Node,
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

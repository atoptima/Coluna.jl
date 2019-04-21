abstract type AbstractReformulationSolver end

function apply end

function apply(T::Type{<:AbstractReformulationSolver}, f::Reformulation)
    error("Apply function not implemented for solver type ", T)
end

struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    priority_function::Function
end

SearchTree(search_strategy::SEARCHSTRATEGY) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward),
    build_priority_function(search_strategy)
)

getnodes(t::SearchTree) = t.nodes
Base.isempty(t::SearchTree) = isempty(t.nodes)
add_node(t::SearchTree, node::Node) = DS.enqueue!(
    t.nodes, node, t.priority_function(node)
)
pop_node!(t::SearchTree) = DS.dequeue!(t.nodes)
nb_open_nodes(t::SearchTree) = length(t.nodes)

function build_priority_function(strategy::SEARCHSTRATEGY)
    strategy == DepthFirst && return x->(-x.depth)
    strategy == BestDualBound && return x->x.node_inc_lp_dual_bound
end

mutable struct TreeSolver <: AbstractReformulationSolver
    primary_tree::SearchTree
    secondary_tree::SearchTree
    in_primary::Bool
    treat_order::Int
    nb_treated_nodes::Int
    incumbents::Incumbents
end

function TreeSolver(search_strategy::SEARCHSTRATEGY,
                    ObjSense::Type{<:AbstractObjSense})
    return TreeSolver(
        SearchTree(search_strategy), SearchTree(DepthFirst),
        true, 0, 0, Incumbents(ObjSense)
    )
end

get_primary_tree(s::TreeSolver) = s.primary_tree
get_secondary_tree(s::TreeSolver) = s.secondary_tree
cur_tree(s::TreeSolver) = (s.in_primary ? s.primary_tree : s.secondary_tree)
Base.isempty(s::TreeSolver) = isempty(cur_tree(s))
add_node(s::TreeSolver, node::Node) = add_node(cur_tree(s), node)
pop_node!(s::TreeSolver) = pop_node!(cur_tree(s))
nb_open_nodes(s::TreeSolver) = (nb_open_nodes(s.primary_tree)
                                + nb_open_nodes(s.secondary_tree))
get_treat_order(s::TreeSolver) = s.treat_order
get_nb_treated_nodes(s::TreeSolver) = s.nb_treated_nodes
get_incumbents(s::TreeSolver) = s.incumbents
switch_tree(s::TreeSolver) = s.in_primary = !s.in_primary
getincumbents(s::TreeSolver) = s.incumbents

function apply(::Type{<:TreeSolver}, f::Reformulation)
    tree_solver = TreeSolver(_params_.search_strategy, f.master.obj_sense)
    add_node(tree_solver, RootNode(f.master.obj_sense))

    # Node strategy
    strategy = MockStrategy # Should be kept in reformulation?
    r = StrategyRecord()

    while (!isempty(tree_solver)
           && get_nb_treated_nodes(tree_solver) < _params_.max_num_nodes)

        cur_node = pop_node!(tree_solver)
        print_info_before_apply(cur_node, tree_solver)

        apply(strategy, f, cur_node, r, nothing)

        print_info_after_apply(cur_node, tree_solver)
        update_tree_solver(tree_solver, cur_node)
    end
end

function update_primals(s::TreeSolver, n_incumbents::Incumbents)
    s_incumbents = getincumbents(s)
    if isbetter(get_ip_primal_bound(n_incumbents),
                get_ip_primal_bound(s_incumbents))
        s_incumbents.ip_primal_sol = copy(get_ip_primal_sol(n_incumbents))
    end
end

function update_duals(s::TreeSolver, n_incumbents::Incumbents)
    s_incumbents = getincumbents(s)
    worst_bound = get_ip_dual_bound(n_incumbents)
    for n in getnodes(get_primary_tree(s))
        db = get_ip_dual_bound(getincumbents(n))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for n in getnodes(get_secondary_tree(s))
        db = get_ip_dual_bound(getincumbents(n))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    s_incumbents.ip_dual_bound = worst_bound
end

function update_bounds(s::TreeSolver, n_incumbents::Incumbents)
    update_primals(s, n_incumbents)
    update_duals(s, n_incumbents)
end

function update_tree_solver(s::TreeSolver, n::Node)
    s.treat_order += 1
    s.nb_treated_nodes += 1
    t = cur_tree(s)
    if !to_be_pruned(n)
        add_node(t, n)
    end
    if ((nb_open_nodes(s) + length(n.children))
        >= _params_.open_nodes_limit)
        switch_tree(s)
        t = cur_tree(s)
    end
    for idx in length(n.children):-1:1
        add_node(t, pop!(n.children))
    end
    update_bounds(s, getincumbents(n))
end

function print_info_before_apply(n::Node, s::TreeSolver)
    print(nb_open_nodes(s))
    print(" open nodes. Treating node ", get_treat_order(n))
    getparent(n) == nothing && println()
    getparent(n) != nothing && println("Parent is ", get_treat_order(getparent(n)))

    solver_incumbents = getincumbents(s)
    node_incumbents = getincumbents(n)
    db = get_ip_dual_bound(solver_incumbents)
    pb = get_ip_primal_bound(solver_incumbents)
    node_db = get_ip_dual_bound(node_incumbents)

    print("Current best known bounds : ")
    printbounds(db, pb)
    println()
    println("Elapsed time: ", _elapsed_solve_time(), " seconds")
    println("Subtree dual bound is ", node_db)
    println("Branching constraint:  ")
    # coluna_print(n.local_branching_constraints[1])
    println("************************************************************")
    return
end

function print_info_after_apply(n::Node, s::TreeSolver)
    println("************************************************************")
    println("Node ", get_treat_order(n), " is treated")
    println("Generated ", length(getchildren(n)), " children nodes")
    println("************************************************************")
    return
end

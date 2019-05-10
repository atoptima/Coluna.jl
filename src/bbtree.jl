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

function pushnode!(t::SearchTree, node::Node)
    DS.enqueue!(
        t.nodes, node, t.priority_function(node)
    )
end

popnode!(t::SearchTree) = DS.dequeue!(t.nodes)
nb_open_nodes(t::SearchTree) = length(t.nodes)

function build_priority_function(strategy::SEARCHSTRATEGY)
    strategy == DepthFirst && return x->(-x.depth)
    strategy == BestDualBound && return x->(get_lp_dual_bound(x.incumbents))
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
        true, 1, 0, Incumbents(ObjSense)
    )
end

get_primary_tree(s::TreeSolver) = s.primary_tree
get_secondary_tree(s::TreeSolver) = s.secondary_tree
cur_tree(s::TreeSolver) = (s.in_primary ? s.primary_tree : s.secondary_tree)
Base.isempty(s::TreeSolver) = isempty(cur_tree(s))
pushnode!(s::TreeSolver, node::Node) = pushnode!(cur_tree(s), node)
popnode!(s::TreeSolver) = popnode!(cur_tree(s))
nb_open_nodes(s::TreeSolver) = (nb_open_nodes(s.primary_tree)
                                + nb_open_nodes(s.secondary_tree))
get_treat_order(s::TreeSolver) = s.treat_order
get_nb_treated_nodes(s::TreeSolver) = s.nb_treated_nodes
getincumbents(s::TreeSolver) = s.incumbents
switch_tree(s::TreeSolver) = s.in_primary = !s.in_primary

function apply_on_node!(alg_strategy::Type{<:AbstractAlgorithmStrategy},
                       branch_strategy::Type{<:AbstractBranchingStrategy},
                       reform::Reformulation, node::Node, strategy_rec, 
                       params)
    # Check if it needs to be treated, because pb might have improved
    strategy_rec.do_branching = true
    setup!(reform, node)
    setsolver!(strategy_rec, StartNode)
    apply!(alg_strategy, reform, node, strategy_rec, params)
    if strategy_rec.do_branching
        apply!(branch_strategy, reform, node, strategy_rec, params)
    end
    record!(reform, node)
    return
end

function setup_node!(n::Node, treat_order::Int, tree_incumbents::Incumbents)
    @logmsg LogLevel(-1) "Setting up node before apply"
    set_treat_order!(n, treat_order)
    set_ip_primal_sol!(getincumbents(n), get_ip_primal_sol(tree_incumbents))
    @logmsg LogLevel(-2) string("New IP primal bound is set to ", get_ip_primal_bound(getincumbents(n)))
    if (ip_gap(getincumbents(n)) <= 0.0 + 0.00000001)
        @logmsg LogLevel(-2) string("Gap is non-positive: ", ip_gap(getincumbents(n)), ". Abort treatment.")
        return false
    end
    return true
end

function apply(::Type{<:TreeSolver}, reform::Reformulation)
    tree_solver = TreeSolver(_params_.search_strategy, reform.master.obj_sense)
    pushnode!(tree_solver, RootNode(reform.master.obj_sense))

    # Node strategy
    alg_strategy = SimpleBnP # Should be kept in reformulation?
    branch_strategy = SimpleBranching
    strategy_record = StrategyRecord()

    while (!isempty(tree_solver)
           && get_nb_treated_nodes(tree_solver) < _params_.max_num_nodes)

        cur_node = popnode!(tree_solver)
        should_apply = setup_node!(
            cur_node, get_treat_order(tree_solver), getincumbents(tree_solver)
        )
        print_info_before_apply(cur_node, tree_solver, reform, should_apply)
        should_apply && apply_on_node!(alg_strategy, branch_strategy, reform, cur_node, strategy_record, nothing)
        print_info_after_apply(cur_node, tree_solver)
        update_tree_solver(tree_solver, cur_node)
    end

end

function updateprimals!(tree::TreeSolver, cur_node_incumbents::Incumbents)
    tree_incumbents = getincumbents(tree)
    set_ip_primal_sol!(
        tree_incumbents, copy(get_ip_primal_sol(cur_node_incumbents))
    )
    return
end

function updateduals!(tree::TreeSolver, cur_node_incumbents::Incumbents)
    tree_incumbents = getincumbents(tree)
    worst_bound = get_ip_dual_bound(cur_node_incumbents)
    for (node, priority) in getnodes(get_primary_tree(tree))
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for (node, priority) in getnodes(get_secondary_tree(tree))
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    set_ip_dual_bound!(tree_incumbents, worst_bound)
    return
end

function updatebounds!(tree::TreeSolver, cur_node::Node)
    cur_node_incumbents = getincumbents(cur_node)
    updateprimals!(tree, cur_node_incumbents)
    updateduals!(tree, cur_node_incumbents)
end

function update_tree_solver(s::TreeSolver, n::Node)
    s.treat_order += 1
    s.nb_treated_nodes += 1
    t = cur_tree(s)
    if !to_be_pruned(n)
        pushnode!(t, n)
    end
    if ((nb_open_nodes(s) + length(n.children))
        >= _params_.open_nodes_limit)
        switch_tree(s)
        t = cur_tree(s)
    end
    for idx in length(n.children):-1:1
        pushnode!(t, pop!(n.children))
    end
    updatebounds!(s, n)
end

function print_info_before_apply(n::Node, s::TreeSolver, reform::Reformulation, strategy_was_applied::Bool)
    println("************************************************************")
    print(nb_open_nodes(s) + 1)
    print(" open nodes. Treating node ", get_treat_order(s), ". ")
    getparent(n) == nothing && println()
    getparent(n) != nothing && println("Parent is ", get_treat_order(getparent(n)))
    if !strategy_was_applied
        println("Node ", get_treat_order(n), " is conquered, no need to apply strategy.")
    end

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
    branch = getbranch(n)
    if branch != nothing
        print("Branching constraint: ")
        show(stdout, branch, getmaster(reform))
        println(" ")
    end
    println("************************************************************")
    return
end

function print_info_after_apply(n::Node, s::TreeSolver)
    println("************************************************************")
    println("Node ", get_treat_order(n), " is treated")
    println("Generated ", length(getchildren(n)), " children nodes")

    node_incumbents = getincumbents(n)
    db = get_ip_dual_bound(node_incumbents)
    pb = get_ip_primal_bound(node_incumbents)

    print("Node bounds after treatment : ")
    printbounds(db, pb)
    println()

    # Removed the following prints because they are printed in the function print_info_before_apply
    # and because since the children of a node is poped, we were printing "generated 0 children" every time
    # node_incumbents = getincumbents(s)
    # db = get_ip_dual_bound(node_incumbents)
    # pb = get_ip_primal_bound(node_incumbents)
    # print("Tree bounds : ")
    # printbounds(db, pb)
    # println(" ")
    println("************************************************************")
    return
end

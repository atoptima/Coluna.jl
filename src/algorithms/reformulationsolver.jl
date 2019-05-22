struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    search_strategy::Type{<:AbstractTreeSearchStrategy}
end

SearchTree(search_strategy::Type{<:AbstractTreeSearchStrategy}) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), search_strategy
)

getnodes(t::SearchTree) = t.nodes
Base.isempty(t::SearchTree) = isempty(t.nodes)

push!(t::SearchTree, node::Node) = DS.enqueue!(t.nodes, node, apply!(t.search_strategy, node))
popnode!(t::SearchTree) = DS.dequeue!(t.nodes)
nb_open_nodes(t::SearchTree) = length(t.nodes)

mutable struct ReformulationSolverRecord <: AbstractAlgorithmRecord
    feasible::Bool
    incumbents::Incumbents
end

mutable struct ReformulationSolver <: AbstractAlgorithm
    primary_tree::SearchTree
    secondary_tree::SearchTree
    in_primary::Bool
    treat_order::Int
    nb_treated_nodes::Int
    incumbents::Incumbents
    found_feasible_sol::Bool
end

function ReformulationSolver(search_strategy::Type{<:AbstractTreeSearchStrategy},
                    ObjSense::Type{<:AbstractObjSense})
    return ReformulationSolver(
        SearchTree(search_strategy), SearchTree(DepthFirst),
        true, 1, 0, Incumbents(ObjSense), false
    )
end

get_primary_tree(s::ReformulationSolver) = s.primary_tree
get_secondary_tree(s::ReformulationSolver) = s.secondary_tree
cur_tree(s::ReformulationSolver) = (s.in_primary ? s.primary_tree : s.secondary_tree)
Base.isempty(s::ReformulationSolver) = isempty(cur_tree(s))
push!(s::ReformulationSolver, node::Node) = push!(cur_tree(s), node)
popnode!(s::ReformulationSolver) = popnode!(cur_tree(s))
nb_open_nodes(s::ReformulationSolver) = (nb_open_nodes(s.primary_tree)
                                + nb_open_nodes(s.secondary_tree))
get_treat_order(s::ReformulationSolver) = s.treat_order
get_nb_treated_nodes(s::ReformulationSolver) = s.nb_treated_nodes
getincumbents(s::ReformulationSolver) = s.incumbents
switch_tree(s::ReformulationSolver) = s.in_primary = !s.in_primary

function apply_on_node!(conquer_strategy::Type{<:AbstractConquerStrategy},
                       divide_strategy::Type{<:AbstractDivideStrategy},
                       reform::Reformulation, node::Node, params)
    strategy_rec = StrategyRecord()
    setalgorithm!(strategy_rec, StartNode) # ToClean
    apply!(conquer_strategy, reform, node, strategy_rec, params)
    apply!(divide_strategy, reform, node, strategy_rec, params)
    # Condition needed because if the last algorithm that was executed did a 
    # record (because would change the formulation), the following line 
    # would record the modified problem, which we do not want
    !node.status.need_to_prepare && record!(reform, node)
    return
end

function setup_node!(n::Node, treat_order::Int, tree_incumbents::Incumbents)
    @logmsg LogLevel(0) string("Setting up node ", treat_order, " before apply")
    set_treat_order!(n, treat_order)
    set_ip_primal_sol!(getincumbents(n), get_ip_primal_sol(tree_incumbents))
    @logmsg LogLevel(-1) string("Node IP DB: ", get_ip_dual_bound(getincumbents(n)))
    @logmsg LogLevel(-1) string("Tree IP PB: ", get_ip_primal_bound(getincumbents(n)))
    if (ip_gap(getincumbents(n)) <= 0.0 + 0.00000001)
        @logmsg LogLevel(-1) string("IP Gap is non-positive: ", ip_gap(getincumbents(n)), ". Abort treatment.")
        return false
    end
    @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")
    return true
end

function apply!(::Type{<:ReformulationSolver}, reform::Reformulation)
    # Get all strategies
    conquer_strategy = reform.strategy.conquer
    divide_strategy = reform.strategy.divide
    tree_search_strategy = reform.strategy.tree_search

    reform_solver = ReformulationSolver(tree_search_strategy, reform.master.obj_sense)
    push!(reform_solver, RootNode(reform.master.obj_sense))

    while (!isempty(reform_solver)
           && get_nb_treated_nodes(reform_solver) < _params_.max_num_nodes)

        cur_node = popnode!(reform_solver)
        should_apply = setup_node!(
            cur_node, get_treat_order(reform_solver), getincumbents(reform_solver)
        )
        print_info_before_apply(cur_node, reform_solver, reform, should_apply)
        if should_apply
            apply_on_node!(
                conquer_strategy, divide_strategy, reform, cur_node, nothing
            )
        end
        print_info_after_apply(cur_node, reform_solver)
        update_reform_solver(reform_solver, cur_node)
    end
    return ReformulationSolverRecord(
        reform_solver.found_feasible_sol, getincumbents(reform_solver)
    )
end

function apply!(::Type{<:GlobalStrategy}, reform::Reformulation)
    solver_record = apply!(ReformulationSolver, reform)
    return OptimizationResult{getobjsense(reform.master)}(solver_record.feasible,
        get_ip_primal_bound(solver_record.incumbents),
        get_ip_dual_bound(solver_record.incumbents),
        [get_ip_primal_sol(solver_record.incumbents)],
        typeof(get_lp_dual_sol(solver_record.incumbents))[]
    )
end

function updateprimals!(tree::ReformulationSolver, cur_node_incumbents::Incumbents)
    tree_incumbents = getincumbents(tree)
    set_ip_primal_sol!(
        tree_incumbents, copy(get_ip_primal_sol(cur_node_incumbents))
    )
    return
end

function updateduals!(tree::ReformulationSolver, cur_node_incumbents::Incumbents)
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

function updatebounds!(tree::ReformulationSolver, cur_node::Node)
    cur_node_incumbents = getincumbents(cur_node)
    updateprimals!(tree, cur_node_incumbents)
    updateduals!(tree, cur_node_incumbents)
end

function update_reform_solver(s::ReformulationSolver, n::Node)
    @logmsg LogLevel(0) string("Updating tree.")
    s.treat_order += 1
    s.nb_treated_nodes += 1
    if !n.status.proven_infeasible
        s.found_feasible_sol = true
    end
    t = cur_tree(s)
    if !to_be_pruned(n)
        @logmsg LogLevel(-1) string("Node should not be pruned. Re-inserting in the tree.")
        push!(t, n)
    end
    if ((nb_open_nodes(s) + length(n.children))
        >= _params_.open_nodes_limit)
        switch_tree(s)
        t = cur_tree(s)
    end
    @logmsg LogLevel(-1) string("Inserting ", length(n.children), " children nodes in tree.")
    for idx in length(n.children):-1:1
        push!(t, pop!(n.children))
    end
    updatebounds!(s, n)
end

function print_info_before_apply(n::Node, s::ReformulationSolver, reform::Reformulation, strategy_was_applied::Bool)
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

function print_info_after_apply(n::Node, s::ReformulationSolver)
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

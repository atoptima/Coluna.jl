mutable struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    explore_strategy::AbstractExploreStrategy
    fully_explored::Bool
end

SearchTree(explore_strategy::AbstractExploreStrategy) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), explore_strategy,
    true
)

getnodes(t::SearchTree) = t.nodes
Base.isempty(t::SearchTree) = isempty(t.nodes)

push!(t::SearchTree, node::Node) = DS.enqueue!(t.nodes, node, apply!(t.explore_strategy, node))
popnode!(t::SearchTree) = DS.dequeue!(t.nodes)
nb_open_nodes(t::SearchTree) = length(t.nodes)
was_fully_explored(t::SearchTree) = t.fully_explored

"""
    ReformulationSolver

Branch-and-bound algorithm to optimize a `Reformulation`.
"""
mutable struct ReformulationSolver <: AbstractAlgorithm
    primary_tree::SearchTree
    secondary_tree::SearchTree
    in_primary::Bool
    treat_order::Int
    nb_treated_nodes::Int
    result::OptimizationResult
end

function ReformulationSolver(explore_strategy::AbstractExploreStrategy,
                    ObjSense::Type{<:AbstractObjSense})
    return ReformulationSolver(
        SearchTree(explore_strategy), SearchTree(DepthFirst()),
        true, 1, 0, OptimizationResult{ObjSense}()
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
getresult(s::ReformulationSolver) = s.result
switch_tree(s::ReformulationSolver) = s.in_primary = !s.in_primary

function apply_on_node!(conquer_strategy::AbstractConquerStrategy,
                       divide_strategy::AbstractDivideStrategy,
                       reform::Reformulation, node::Node)
    # Prepare formulation before calling `apply!(::AbstractStrategy)`
    if !istreated(node)
        prepare!(reform, node)
        apply!(conquer_strategy, reform, node)
        record!(reform, node)
    end
    if !to_be_pruned(node)        
        apply!(divide_strategy, reform, node)
    end
    # Condition needed because if the last algorithm that was executed did a 
    # record (because would change the formulation), the following line 
    # would record the modified problem, which we do not want
    # !node.status.need_to_prepare && record!(reform, node)
    # Ruslan : Commented because record should be done before divide strategy. 
    # I am going to redesign node recording and setup. 
    # For the moment, to make it more simple, we always record (before divide).
    return
end

function setup_node!(n::Node, treat_order::Int, res::OptimizationResult)
    @logmsg LogLevel(0) string("Setting up node ", treat_order, " before apply")
    set_treat_order!(n, treat_order)
    nbprimalsols(res) >= 1 && update_ip_primal_sol!(getincumbents(n), unsafe_getbestprimalsol(res))
    @logmsg LogLevel(-1) string("Node IP DB: ", get_ip_dual_bound(getincumbents(n)))
    @logmsg LogLevel(-1) string("Tree IP PB: ", get_ip_primal_bound(getincumbents(n)))
    if (ip_gap(getincumbents(n)) <= 0.0 + 0.00000001)
        @logmsg LogLevel(-1) string("IP Gap is non-positive: ", ip_gap(getincumbents(n)), ". Abort treatment.")
        return false
    end
    @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")
    return true
end

function run_reform_solver!(reform::Reformulation, strategy::GlobalStrategy)
    # Get all strategies
    conquer_strategy = strategy.conquer
    divide_strategy = strategy.divide
    explore_strategy = strategy.explore

    reform_solver = ReformulationSolver(
        explore_strategy, reform.master.obj_sense
    )
    push!(reform_solver, RootNode(reform.master.obj_sense))

    while (!isempty(reform_solver)
           && get_nb_treated_nodes(reform_solver) < _params_.max_num_nodes)

        cur_node = popnode!(reform_solver)
        should_apply = setup_node!(
            cur_node, get_treat_order(reform_solver), getresult(reform_solver)
        )
        print_info_before_apply(cur_node, reform_solver, reform, should_apply)
        if should_apply
            apply_on_node!(conquer_strategy, divide_strategy, reform, cur_node)
        end
        update_reform_solver(reform_solver, cur_node)
    end
    res = getresult(reform_solver)
    tree_fully_explored = (
        was_fully_explored(get_primary_tree(reform_solver))
        && was_fully_explored(get_secondary_tree(reform_solver))
        && get_nb_treated_nodes(reform_solver) < _params_.max_num_nodes
    )
    determine_statuses(res, tree_fully_explored)
    return res
end

function updateprimals!(solver::ReformulationSolver, cur_node_incumbents::Incumbents{S}) where{S}
    if isbetter(getbound(get_ip_primal_sol(cur_node_incumbents)), PrimalBound{S}())
        add_primal_sol!(getresult(solver), copy(get_ip_primal_sol(cur_node_incumbents)))
    end
    return
end

function updateduals!(solver::ReformulationSolver, cur_node_incumbents::Incumbents)
    result = getresult(solver)
    worst_bound = get_ip_dual_bound(cur_node_incumbents)
    for (node, priority) in getnodes(get_primary_tree(solver))
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for (node, priority) in getnodes(get_secondary_tree(solver))
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    setdualbound!(result, worst_bound)
    return
end

function updatebounds!(solver::ReformulationSolver, cur_node::Node)
    cur_node_incumbents = getincumbents(cur_node)
    updateprimals!(solver, cur_node_incumbents)
    updateduals!(solver, cur_node_incumbents)
    return
end

function update_reform_solver(s::ReformulationSolver, n::Node)
    @logmsg LogLevel(0) string("Updating tree.")
    s.treat_order += 1
    s.nb_treated_nodes += 1
    t = cur_tree(s)

    if ((nb_open_nodes(s) + length(n.children)) >= _params_.open_nodes_limit)
        switch_tree(s)
        t = cur_tree(s)
    end
    @logmsg LogLevel(-1) string("Inserting ", length(n.children), " children nodes in tree.")
    for idx in length(n.children):-1:1
        push!(t, pop!(n.children))
    end
    updatebounds!(s, n)
    return
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

    node_incumbents = getincumbents(n)
    db = getdualbound(getresult(s))
    pb = getprimalbound(getresult(s))
    node_db = get_ip_dual_bound(node_incumbents)

    print("Current best known bounds : ")
    printbounds(db, pb)
    println()
    @printf "Elapsed time: %.2f seconds\n" _elapsed_solve_time()
    println("Subtree dual bound is ", node_db)

    branch = getbranch(n)
    if n.branchdescription != ""
        println("Branching constraint: ", n.branchdescription)
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

    println("************************************************************")
    return
end

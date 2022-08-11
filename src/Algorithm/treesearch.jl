"""
    Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg::AbstractConquerAlgorithm = ColCutGenConquer(),
        dividealg::AbstractDivideAlgorithm = SimpleBranching(),
        explorestrategy::AbstractExploreStrategy = DepthFirstStrategy(),
        maxnumnodes::Int = 100000,
        opennodeslimit::Int = 100,
        opt_atol::Float64 = DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = DEF_OPTIMALITY_RTOL,
        branchingtreefile = nothing
    )

This algorithm is a branch and bound that uses a search tree to optimize the reformulation.
At each node in the tree, it applies `conqueralg` to improve the bounds, 
`dividealg` to generate child nodes, and `explorestrategy`
to select the next node to treat.

Parameters : 
- `maxnumnodes` : maximum number of nodes explored by the algorithm
- `opennodeslimit` : maximum number of nodes waiting to be explored
- `opt_atol` : optimality absolute tolerance (alpha)
- `opt_rtol` : optimality relative tolerance (alpha)

Options :
- `branchingtreefile` : name of the file in which the algorithm writes an overview of the branching tree
"""
@with_kw struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColCutGenConquer()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000
    opennodeslimit::Int64 = 100 
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL
    branchingtreefile::Union{Nothing, String} = nothing
    skiprootnodeconquer = false # true for diving heuristics
    storelpsolution = false
    print_node_info = true
end

# Priority of nodes depends on the explore strategy.
priority(::AbstractExploreStrategy, ::Node) = error("todo")
priority(::DepthFirstStrategy, n::Node) = -n.depth
priority(::BestDualBoundStrategy, n::Node) = get_ip_dual_bound(n.optstate)

mutable struct TreeSearchSpace <: AbstractColunaSearchSpace
    reformulation::Reformulation
    conquer::AbstractConquerAlgorithm
    divide::AbstractDivideAlgorithm
    max_num_nodes::Int64
    open_nodes_limit::Int64
    opt_atol::Float64
    opt_rtol::Float64
    previous::Union{Nothing,Node}
    optstate::OptimizationState # from TreeSearchRuntimeData
    exploitsprimalsolutions::Bool # from TreeSearchRuntimeData
    conquer_units_to_restore::UnitsUsage # from TreeSearchRuntimeData
end

get_reformulation(sp::TreeSearchSpace) = sp.reformulation
get_conquer(sp::TreeSearchSpace) = sp.conquer
get_divide(sp::TreeSearchSpace) = sp.divide
get_previous(sp::TreeSearchSpace) = sp.previous
set_previous!(sp::TreeSearchSpace, previous::Node) = sp.previous = previous

search_space_type(::TreeSearchAlgorithm) = TreeSearchSpace

function new_space(
    ::Type{TreeSearchSpace}, algo::TreeSearchAlgorithm, reform::Reformulation, input
)
    exploitsprimalsols = exploits_primal_solutions(algo.conqueralg) || exploits_primal_solutions(algo.dividealg)
    optstate = OptimizationState(
        getmaster(reform), getoptstate(input), exploitsprimalsols, false
    )
    conquer_units_to_restore = UnitsUsage()
    collect_units_to_restore!(conquer_units_to_restore, algo.conqueralg, reform) 
    return TreeSearchSpace(
        reform,
        algo.conqueralg,
        algo.dividealg,
        algo.maxnumnodes,
        algo.opennodeslimit,
        algo.opt_atol,
        algo.opt_rtol,
        nothing,
        optstate,
        exploitsprimalsols,
        conquer_units_to_restore
    )
end

function new_root(sp::TreeSearchSpace, input)
    skipconquer = false # TODO: used for the diving that should be a separate algorithm.
    nodestate = OptimizationState(getmaster(sp.reformulation), getoptstate(input), false, false)
    tree_order = skipconquer ? 0 : -1
    return Node(
        tree_order, 0, nothing, nodestate, "", store_records!(sp.reformulation), false
    )
end

function run!(algo::TreeSearchAlgorithm, env::Env, reform::Reformulation, input::OptimizationInput)
    search_space = new_space(search_space_type(algo), algo, reform, input)
    return tree_search(algo.explorestrategy, search_space, env, input)
end

function after_conquer!(space::TreeSearchSpace, current, output)
    nodestate = current.optstate
    treestate = space.optstate

    store_records!(space.reformulation, current.recordids)
    current.conquerwasrun = true
    add_ip_primal_sols!(treestate, get_ip_primal_sols(nodestate)...)
    # TreeSearchAlgorithm returns the primal LP & the dual solution found at the root node
    best_lp_primal_sol = get_best_lp_primal_sol(nodestate)
    # We consider that the algorithm will always store the lp solution.
    if isrootnode(current) && !isnothing(best_lp_primal_sol)
        set_lp_primal_sol!(treestate, best_lp_primal_sol) 
    end
    best_lp_dual_sol = get_best_lp_dual_sol(nodestate)
    if isrootnode(current) && !isnothing(best_lp_dual_sol)
        set_lp_dual_sol!(treestate, best_lp_dual_sol)
    end
    return
end


# Conquer
function get_input(::AbstractConquerAlgorithm, space::TreeSearchSpace, current::Node)
    space_state = space.optstate
    node_state = current.optstate
    update_ip_primal_bound!(node_state, get_ip_primal_bound(space_state))

    # TODO: improve ?
    # Condition 1: IP Gap is closed. Abort treatment.
    # Condition 2: in the case the conquer was already run (in strong branching),
    # we still need to update the node IP primal bound before exiting 
    # (to possibly avoid branching)
    run_conquer = !ip_gap_closed(node_state, rtol = space.opt_rtol, atol = space.opt_atol) || !current.conquerwasrun

    # TODO: At the moment, we consider that there is no algorithm that exploits
    # the ip primal solution.
    # best_ip_primal_sol = get_best_ip_primal_sol(nodestate)
    # if tsdata.exploitsprimalsolutions && best_ip_primal_sol !== nothing
    #     set_ip_primal_sol!(treestate, best_ip_primal_sol)
    # end

    return ConquerInput(current, space.conquer_units_to_restore, run_conquer)
end

function get_input(::AbstractDivideAlgorithm, space::TreeSearchSpace, node::Node)
    return DivideInput(node, space.optstate)
end

function new_children(space::AbstractColunaSearchSpace, candidates, node::Node)
    add_ip_primal_sols!(space.optstate, get_ip_primal_sols(getoptstate(candidates))...)
    children = map(candidates.children) do child
        # tree_order
        return Node(child, -1)
    end
    return children
end

function _updatedualbound!(space, reform::Reformulation, untreated_nodes)
    treestate = space.optstate

    worst_bound = mapreduce(
        node -> get_ip_dual_bound(getoptstate(node)),
        worst,
        untreated_nodes;
        init = DualBound(reform, getvalue(get_ip_primal_bound(treestate)))
    )

    set_ip_dual_bound!(treestate, worst_bound)
    return
end

function node_change!(previous::Node, current::Node, space::TreeSearchSpace, untreated_nodes)
    println("\e[45m node change ! \e[00m")
    _updatedualbound!(space, space.reformulation, untreated_nodes) # this method needs to be reimplemented.
    remove_records!(previous.recordids)

    # we delete solutions from the node optimization state, as they are not needed anymore
    nodestate = getoptstate(previous)
    empty_ip_primal_sols!(nodestate)
    empty_lp_primal_sols!(nodestate)
    empty_lp_dual_sols!(nodestate)
end

function tree_search_output(space::TreeSearchSpace, untreated_nodes)
    if isempty(untreated_nodes) # it means that the BB tree has been fully explored
        if length(get_ip_primal_sols(space.optstate)) >= 1
            if ip_gap_closed(space.optstate, rtol = space.opt_rtol, atol = space.opt_atol)
                setterminationstatus!(space.optstate, OPTIMAL)
            else
                setterminationstatus!(space.optstate, OTHER_LIMIT)
            end
        else
            setterminationstatus!(space.optstate, INFEASIBLE)
        end
    else
        setterminationstatus!(space.optstate, OTHER_LIMIT)
    end

    # Clear untreated nodes
    while !isempty(untreated_nodes)
        node = pop!(untreated_nodes)
        remove_records!(node.recordids)
    end

    #env.kpis.node_count = 0 #get_tree_order(tsdata) - 1 # TODO : check why we need to remove 1

    return OptimizationOutput(space.optstate)
end

############################################################################################
############################################################################################
############################################################################################
############################################################################################
################################## OLD CODE BELOW ##########################################
############################################################################################
############################################################################################
############################################################################################
############################################################################################
############################################################################################
############################################################################################

# """
#     AbstractTreeExploreStrategy

#     Strategy for the tree exploration

# """
# abstract type AbstractTreeExploreStrategy end

# getnodevalue(strategy::AbstractTreeExploreStrategy, node::Node) = 0

# # Depth-first strategy
# struct DepthFirstStrategy <: AbstractTreeExploreStrategy end
getnodevalue(algo::DepthFirstStrategy, n::Node) = (-n.depth)

# # Best dual bound strategy
# struct BestDualBoundStrategy <: AbstractTreeExploreStrategy end
getnodevalue(algo::BestDualBoundStrategy, n::Node) = get_ip_dual_bound(n.optstate)

"""
    SearchTree
"""
mutable struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    strategy::AbstractExploreStrategy
end

SearchTree(strategy::AbstractExploreStrategy) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), strategy
)

getnodes(tree::SearchTree) = tree.nodes
treeisempty(tree::SearchTree) = DS.isempty(tree.nodes)

push!(tree::SearchTree, node::Node) = DS.enqueue!(tree.nodes, node, getnodevalue(tree.strategy, node))
popnode!(tree::SearchTree) = DS.dequeue!(tree.nodes)
nb_open_nodes(tree::SearchTree) = length(tree.nodes)

"Data used by the tree search algorithm while running. Destroyed after each run."
mutable struct TreeSearchRuntimeData
    primary_tree::SearchTree
    max_primary_tree_size::Int64
    secondary_tree::SearchTree
    tree_order::Int64
    optstate::OptimizationState
    exploitsprimalsolutions::Bool
    conquer_units_to_restore::UnitsUsage
end

function TreeSearchRuntimeData(algo::TreeSearchAlgorithm, reform::Reformulation, input::OptimizationInput)
    exploitsprimalsols = exploits_primal_solutions(algo.conqueralg) || exploits_primal_solutions(algo.dividealg)        
    treestate = OptimizationState(
        getmaster(reform), getoptstate(input), exploitsprimalsols, false
    )

    conquer_units_to_restore = UnitsUsage()
    collect_units_to_restore!(conquer_units_to_restore, algo.conqueralg, reform) 
    # divide algorithms are always manager algorithms, so we do not need to restore storage units for them

    tsdata = TreeSearchRuntimeData(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()),
        1, treestate, exploitsprimalsols, conquer_units_to_restore
    )
    master = getmaster(reform)
    push!(tsdata, RootNode(master, getoptstate(input), store_records!(reform), algo.skiprootnodeconquer))
    return tsdata
end

treeisempty(data::TreeSearchRuntimeData) = treeisempty(data.primary_tree) && treeisempty(data.secondary_tree)
primary_tree_is_full(data::TreeSearchRuntimeData) = nb_open_nodes(data.primary_tree) >= data.max_primary_tree_size

function push!(data::TreeSearchRuntimeData, node::Node) 
    if primary_tree_is_full(data) 
        push!(data.secondary_tree, node)
    else           
        push!(data.primary_tree, node)
    end
end

function popnode!(data::TreeSearchRuntimeData)::Node
    if treeisempty(data.secondary_tree)
        return popnode!(data.primary_tree)
    end
    return popnode!(data.secondary_tree)
end

function nb_open_nodes(data::TreeSearchRuntimeData)
    return nb_open_nodes(data.primary_tree) + nb_open_nodes(data.secondary_tree)
end

get_tree_order(data::TreeSearchRuntimeData) = data.tree_order
getoptstate(data::TreeSearchRuntimeData) = data.optstate

#TreeSearchAlgorithm is a manager algorithm (manages storing and restoring storage units)
ismanager(algo::TreeSearchAlgorithm) = true

# TreeSearchAlgorithm does not use any record itself, 
# therefore get_units_usage() is not defined for it

function get_child_algorithms(algo::TreeSearchAlgorithm, reform::Reformulation) 
    return [(algo.conqueralg, reform), (algo.dividealg, reform)]
end

function print_node_info_before_conquer(data::TreeSearchRuntimeData, env::Env, node::Node)
    println("***************************************************************************************")
    if isrootnode(node)
        println("**** BaB tree root node")
    else
        println("**** BaB tree node N° ", get_tree_order(node), 
                ", parent N° ", get_tree_order(getparent(node)),
                ", depth ", getdepth(node),
                ", ", nb_open_nodes(data) + 1, " open nodes")
    end

    db = getvalue(get_ip_dual_bound(getoptstate(data)))
    pb = getvalue(get_ip_primal_bound(getoptstate(data)))
    node_db = getvalue(get_ip_dual_bound(getoptstate(node)))
    @printf "**** Local DB = %.4f," node_db
    @printf " global bounds : [ %.4f , %.4f ]," db pb
    @printf " time = %.2f sec.\n" elapsed_optim_time(env)

    if node.branchdescription != ""
        println("**** Branching constraint: ", node.branchdescription)
    end
    println("***************************************************************************************")
    return
end

# function init_branching_tree_file(algo::TreeSearchAlgorithm)
#     if algo.branchingtreefile !== nothing
#         open(algo.branchingtreefile, "w") do file
#             println(file, "## dot -Tpdf thisfile > thisfile.pdf \n")
#             println(file, "digraph Branching_Tree {")
#             print(file, "\tedge[fontname = \"Courier\", fontsize = 10];}")
#         end
#     end
#     return
# end

# function print_node_in_branching_tree_file(
#     algo::TreeSearchAlgorithm, env::Env, data::TreeSearchRuntimeData, node
# )
#     if algo.branchingtreefile !== nothing
#         pb = getvalue(get_ip_primal_bound(getoptstate(data)))
#         db = getvalue(get_ip_dual_bound(getoptstate(node)))
#         open(algo.branchingtreefile, "r+") do file
#             # rewind the closing brace character
#             seekend(file)
#             pos = position(file)
#             seek(file, pos - 1)

#             # start writing over this character
#             ncur = get_tree_order(node)
#             time = elapsed_optim_time(env)
#             if ip_gap_closed(getoptstate(node))
#                 @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[PRUNED , %.4f]\"];" ncur ncur time pb
#             else
#                 @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[%.4f , %.4f]\"];" ncur ncur time db pb
#             end
#             if !isrootnode(node)
#                 npar = get_tree_order(getparent(node))
#                 @printf file "\n\tn%i -> n%i [label= \"%s\"];}" npar ncur node.branchdescription
#             else
#                 print(file, "}")
#             end
#         end
#     end
#     return
# end

# function finish_branching_tree_file(algo::TreeSearchAlgorithm)
#     if algo.branchingtreefile !== nothing
#         open(algo.branchingtreefile, "r+") do file
#             # rewind the closing brace character
#             seekend(file)
#             pos = position(file)
#             seek(file, pos - 1)

#             # just move the closing brace to the next line
#             println(file, "\n}")
#         end
#     end
#     return
# end

function run_conquer_algorithm!(
    algo::TreeSearchAlgorithm, env::Env, tsdata::TreeSearchRuntimeData,
    reform::Reformulation, node::Node
)
    if (!node.conquerwasrun)
        set_tree_order!(node, tsdata.tree_order)
        tsdata.tree_order += 1
    end

    algo.print_node_info && print_node_info_before_conquer(tsdata, env, node)

    treestate = getoptstate(tsdata)
    nodestate = getoptstate(node)

    update_ip_primal_bound!(nodestate, get_ip_primal_bound(treestate))
    best_ip_primal_sol = get_best_ip_primal_sol(nodestate)
    if tsdata.exploitsprimalsolutions && best_ip_primal_sol !== nothing
        set_ip_primal_sol!(treestate, best_ip_primal_sol)
    end

    # in the case the conquer was already run (in strong branching),
    # we still need to update the node IP primal bound before exiting 
    # (to possibly avoid branching)
    node.conquerwasrun && return

    apply_conquer_alg_to_node!(
        node, algo.conqueralg, env, reform, tsdata.conquer_units_to_restore, 
        algo.opt_rtol, algo.opt_atol
    )        

    add_ip_primal_sols!(treestate, get_ip_primal_sols(nodestate)...)

    # TreeSearchAlgorithm returns the primal LP & the dual solution found at the root node
    best_lp_primal_sol = get_best_lp_primal_sol(nodestate)
    if algo.storelpsolution && isrootnode(node) && best_lp_primal_sol !== nothing
        set_lp_primal_sol!(treestate, best_lp_primal_sol) 
    end

    best_lp_dual_sol = get_best_lp_dual_sol(nodestate)
    if isrootnode(node) && best_lp_dual_sol !== nothing
        set_lp_dual_sol!(treestate, best_lp_dual_sol)
    end
    return
end

function run_divide_algorithm!(
    algo::TreeSearchAlgorithm, env::Env, tsdata::TreeSearchRuntimeData, 
    reform::Reformulation, node::Node
)
    treestate = getoptstate(tsdata)
    output = run!(algo.dividealg, env, reform, DivideInput(node, treestate))

    add_ip_primal_sols!(treestate, get_ip_primal_sols(getoptstate(output))...)

    @logmsg LogLevel(-1) string("Updating tree.")

    children = getchildren(output)
    isempty(children) && return

    first_child_with_runconquer = true
    for child in children
        tree_order = tsdata.tree_order
        if child.conquerwasrun
            tsdata.tree_order += 1
            if first_child_with_runconquer
                print("Child nodes generated :")
                first_child_with_runconquer = false
            end    
            print(" N° ", tree_order ," ")
        end
        push!(tsdata, Node(child, tree_order))
    end
    !first_child_with_runconquer && println()
    return
end

function updatedualbound!(data::TreeSearchRuntimeData, reform::Reformulation)
    treestate = getoptstate(data)
    worst_bound = DualBound(reform, getvalue(get_ip_primal_bound(treestate)))
    for (node, _) in getnodes(data.primary_tree)
        db = get_ip_dual_bound(getoptstate(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end

    for (node, _) in getnodes(data.secondary_tree)
        db = get_ip_dual_bound(getoptstate(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end

    set_ip_dual_bound!(treestate, worst_bound)
    return
end

function _run!(
    algo::TreeSearchAlgorithm, env::Env, reform::Reformulation, input::OptimizationInput
)::OptimizationOutput
    tsdata = TreeSearchRuntimeData(algo, reform, input)

    #init_branching_tree_file(algo)
    while !treeisempty(tsdata) && get_tree_order(tsdata) <= algo.maxnumnodes
        node = popnode!(tsdata)

        # run_conquer_algorithm! updates primal solution the tree search optstate and the 
        # dual bound of the optstate only at the root node.
        run_conquer_algorithm!(algo, env, tsdata, reform, node)
        #print_node_in_branching_tree_file(algo, env, tsdata, node)

        nodestatus = getterminationstatus(node.optstate)
        if nodestatus == OPTIMAL || nodestatus == INFEASIBLE ||
           ip_gap_closed(node.optstate, rtol = algo.opt_rtol, atol = algo.opt_atol)             
            println("Node is already conquered. No children will be generated.")
        elseif nodestatus != TIME_LIMIT
            run_divide_algorithm!(algo, env, tsdata, reform, node)
        end

        updatedualbound!(tsdata, reform)

        remove_records!(node.recordids)
        # we delete solutions from the node optimization state, as they are not needed anymore
        nodestate = getoptstate(node)
        empty_ip_primal_sols!(nodestate)
        empty_lp_primal_sols!(nodestate)
        empty_lp_dual_sols!(nodestate)

        if nodestatus == TIME_LIMIT
            println("Time limit is reached. Tree search is interrupted")
            break
        end
    end
    #finish_branching_tree_file(algo)

    if treeisempty(tsdata) # it means that the BB tree has been fully explored
        if length(get_ip_primal_sols(tsdata.optstate)) >= 1
            if ip_gap_closed(tsdata.optstate, rtol = algo.opt_rtol, atol = algo.opt_atol)
                setterminationstatus!(tsdata.optstate, OPTIMAL)
            else
                setterminationstatus!(tsdata.optstate, OTHER_LIMIT)
            end
        else
            setterminationstatus!(tsdata.optstate, INFEASIBLE)
        end
    else
        setterminationstatus!(tsdata.optstate, OTHER_LIMIT)
    end

    # Clear untreated nodes
    while !treeisempty(tsdata)
        node = popnode!(tsdata)
        remove_records!(node.recordids)
    end

    env.kpis.node_count = get_tree_order(tsdata) - 1 # TODO : check why we need to remove 1

    return OptimizationOutput(tsdata.optstate)
end

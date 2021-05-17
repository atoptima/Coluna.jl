"""
    AbstractTreeExploreStrategy

    Strategy for the tree exploration

"""
abstract type AbstractTreeExploreStrategy end

getnodevalue(strategy::AbstractTreeExploreStrategy, node::Node) = 0

# Depth-first strategy
struct DepthFirstStrategy <: AbstractTreeExploreStrategy end
getnodevalue(algo::DepthFirstStrategy, n::Node) = (-n.depth)

# Best dual bound strategy
struct BestDualBoundStrategy <: AbstractTreeExploreStrategy end
getnodevalue(algo::BestDualBoundStrategy, n::Node) = get_ip_dual_bound(n.optstate)

"""
    Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg::AbstractConquerAlgorithm = ColCutGenConquer(),
        dividealg::AbstractDivideAlgorithm = SimpleBranching(),
        explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy(),
        maxnumnodes::Int = 100000,
        opennodeslimit::Int = 100,
        opt_atol::Float64 = DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = DEF_OPTIMALITY_RTOL,
        branchingtreefile = nothing
    )

This algorithm uses search tree to do optimization. At each node in the tree, it applies
`conqueralg` to improve the bounds, `dividealg` to generate child nodes, and `explorestrategy`
to select the next node to treat.

Parameters : 
- `maxnumnodes` : maximum number of nodes explored by the algorithm
- `opennodeslimit` : maximum number of nodes waiting to be explored.
- `opt_atol` : optimality absolute tolerance
- `opt_rtol` : optimality relative tolerance

Options :
- `branchingtreefile` : name of the file in which the algorithm writes an overview of the
branching tree 
"""
@with_kw struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColCutGenConquer()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000 
    opennodeslimit::Int64 = 100 
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL
    branchingtreefile::Union{Nothing, String} = nothing
    skiprootnodeconquer = false # true for diving heuristics
    storelpsolution = false
    print_node_info = true
end

"""
    SearchTree
"""
mutable struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    strategy::AbstractTreeExploreStrategy
end

SearchTree(strategy::AbstractTreeExploreStrategy) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), strategy
)

getnodes(tree::SearchTree) = tree.nodes
treeisempty(tree::SearchTree) = DS.isempty(tree.nodes)

push!(tree::SearchTree, node::Node) = DS.enqueue!(tree.nodes, node, getnodevalue(tree.strategy, node))
popnode!(tree::SearchTree) = DS.dequeue!(tree.nodes)
nb_open_nodes(tree::SearchTree) = length(tree.nodes)

"""
    TreeSearchRuntimeData

    Data used by the tree search algorithm while running.
    Destroyed after each run.     
"""
mutable struct TreeSearchRuntimeData{Sense}
    primary_tree::SearchTree
    max_primary_tree_size::Int64
    secondary_tree::SearchTree
    tree_order::Int64
    optstate::OptimizationState
    exploitsprimalsolutions::Bool
    Sense::Type{<:Coluna.AbstractSense}
    conquer_units_to_restore::UnitsUsageDict
    worst_db_of_pruned_node::DualBound{Sense}
end

function TreeSearchRuntimeData(algo::TreeSearchAlgorithm, reform::Reformulation, input::OptimizationInput)
    exploitsprimalsols = exploits_primal_solutions(algo.conqueralg) || exploits_primal_solutions(algo.dividealg)        
    treestate = OptimizationState(
        getmaster(reform), getoptstate(input), exploitsprimalsols, false
    )

    conquer_units_to_restore = UnitsUsageDict()
    collect_units_to_restore!(conquer_units_to_restore, algo.conqueralg, reform) 
    # divide algorithms are always manager algorithms, so we do not need to restore storage units for them

    Sense = getobjsense(reform)

    tsdata = TreeSearchRuntimeData{Sense}(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()),
        1, treestate, exploitsprimalsols, Sense, conquer_units_to_restore,
        -DualBound{Sense}()
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

function init_branching_tree_file(algo::TreeSearchAlgorithm)
    if algo.branchingtreefile !== nothing
        open(algo.branchingtreefile, "w") do file
            println(file, "## dot -Tpdf thisfile > thisfile.pdf \n")
            println(file, "digraph Branching_Tree {")
            print(file, "\tedge[fontname = \"Courier\", fontsize = 10];}")
        end
    end
    return
end

function print_node_in_branching_tree_file(
    algo::TreeSearchAlgorithm, env::Env, data::TreeSearchRuntimeData, node
)
    if algo.branchingtreefile !== nothing
        pb = getvalue(get_ip_primal_bound(getoptstate(data)))
        db = getvalue(get_ip_dual_bound(getoptstate(node)))
        open(algo.branchingtreefile, "r+") do file
            # rewind the closing brace character
            seekend(file)
            pos = position(file)
            seek(file, pos - 1)

            # start writing over this character
            ncur = get_tree_order(node)
            time = elapsed_optim_time(env)
            if ip_gap_closed(getoptstate(node))
                @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[PRUNED , %.4f]\"];" ncur ncur time pb
            else
                @printf file "\n\tn%i [label= \"N_%i (%.0f s) \\n[%.4f , %.4f]\"];" ncur ncur time db pb
            end
            if !isrootnode(node)
                npar = get_tree_order(getparent(node))
                @printf file "\n\tn%i -> n%i [label= \"%s\"];}" npar ncur node.branchdescription
            else
                print(file, "}")
            end
        end
    end
    return
end

function finish_branching_tree_file(algo::TreeSearchAlgorithm)
    if algo.branchingtreefile !== nothing
        open(algo.branchingtreefile, "r+") do file
            # rewind the closing brace character
            seekend(file)
            pos = position(file)
            seek(file, pos - 1)

            # just move the closing brace to the next line
            println(file, "\n}")
        end
    end
    return
end

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
    update_ip_primal!(nodestate, treestate, tsdata.exploitsprimalsolutions)

    # in the case the conquer was already run (in strong branching),
    # we still need to update the node IP primal bound before exiting 
    # (to possibly avoid branching)
    node.conquerwasrun && return

    apply_conquer_alg_to_node!(
        node, algo.conqueralg, env, reform, tsdata.conquer_units_to_restore, 
        algo.opt_rtol, algo.opt_atol
    )        

    update_all_ip_primal_solutions!(treestate, nodestate)
    
    if algo.storelpsolution && isrootnode(node) && nb_lp_primal_sols(nodestate) > 0
        set_lp_primal_sol!(treestate, get_best_lp_primal_sol(nodestate)) 
    end 
    return
end

function run_divide_algorithm!(
    algo::TreeSearchAlgorithm, env::Env, tsdata::TreeSearchRuntimeData, 
    reform::Reformulation, node::Node
)
    treestate = getoptstate(tsdata)
    output = run!(algo.dividealg, env, reform, DivideInput(node, treestate))

    update_all_ip_primal_solutions!(treestate, getoptstate(output))

    @logmsg LogLevel(-1) string("Updating tree.")

    children = getchildren(output)
    isempty(children) && return

    first_child_with_runconquer = true
    for child in children
        if (child.conquerwasrun)
            set_tree_order!(child, tsdata.tree_order)
            tsdata.tree_order += 1
            if first_child_with_runconquer
                print("Child nodes generated :")
                first_child_with_runconquer = false
            end    
            print(" N° ", get_tree_order(child) ," ")
        end
        push!(tsdata, child)
    end
    !first_child_with_runconquer && println()
    return
end

function updatedualbound!(data::TreeSearchRuntimeData)
    treestate = getoptstate(data)
    bound_value = getvalue(get_ip_primal_bound(treestate))
    worst_bound = DualBound{data.Sense}(bound_value)  
    for (node, priority) in getnodes(data.primary_tree)
        db = get_ip_dual_bound(getoptstate(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for (node, priority) in getnodes(data.secondary_tree)
        db = get_ip_dual_bound(getoptstate(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    if isbetter(worst_bound, data.worst_db_of_pruned_node)
        worst_bound = data.worst_db_of_pruned_node
    end
    set_ip_dual_bound!(treestate, worst_bound)
    return
end

function run!(
    algo::TreeSearchAlgorithm, env::Env, reform::Reformulation, input::OptimizationInput
)::OptimizationOutput
    tsdata = TreeSearchRuntimeData(algo, reform, input)

    init_branching_tree_file(algo)
    while !treeisempty(tsdata) && get_tree_order(tsdata) <= algo.maxnumnodes
        node = popnode!(tsdata)

        # run_conquer_algorithm! updates primal solution the tree search optstate and the 
        # dual bound of the optstate only at the root node.
        run_conquer_algorithm!(algo, env, tsdata, reform, node)
        print_node_in_branching_tree_file(algo, env, tsdata, node)
               
        nodestatus = getterminationstatus(node.optstate)
        if nodestatus == OPTIMAL || nodestatus == INFEASIBLE ||
           ip_gap_closed(node.optstate, rtol = algo.opt_rtol, atol = algo.opt_atol)             
            println("Node is already conquered. No children will be generated.")
            db = get_ip_dual_bound(node.optstate)
            if isbetter(tsdata.worst_db_of_pruned_node, db)
                tsdata.worst_db_of_pruned_node = db
            end
        elseif nodestatus != TIME_LIMIT
            run_divide_algorithm!(algo, env, tsdata, reform, node)
        end

        updatedualbound!(tsdata)

        remove_records!(node.recordids)
        # we delete solutions from the node optimization state, as they are not needed anymore
        clear_solutions!(getoptstate(node))

        if nodestatus == TIME_LIMIT
            println("Time limit is reached. Tree search is interrupted")
            break
        end
    end
    finish_branching_tree_file(algo)

    if treeisempty(tsdata) # it means that the BB tree has been fully explored
        if nb_ip_primal_sols(tsdata.optstate) >= 1
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
        clear_solutions!(node.optstate)
    end

    env.kpis.node_count = get_tree_order(tsdata) - 1 # TODO : check why we need to remove 1

    return OptimizationOutput(tsdata.optstate)
end

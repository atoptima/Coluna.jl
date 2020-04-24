"""
    AbstractTreeExploreStrategy

    Strategy for the tree exploration

"""
abstract type AbstractTreeExploreStrategy end

getvalue(strategy::AbstractTreeExploreStrategy, node::Node) = 0

# Depth-first strategy
struct DepthFirstStrategy <: AbstractTreeExploreStrategy end
getvalue(algo::DepthFirstStrategy, n::Node) = (-n.depth)

# Best dual bound strategy
struct BestDualBoundStrategy <: AbstractTreeExploreStrategy end
getvalue(algo::BestDualBoundStrategy, n::Node) = get_ip_dual_bound(getincumbents(n))


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
Base.isempty(tree::SearchTree) = isempty(tree.nodes)

push!(tree::SearchTree, node::Node) = DS.enqueue!(tree.nodes, node, getvalue(tree.strategy, node))
popnode!(tree::SearchTree) = DS.dequeue!(tree.nodes)
nb_open_nodes(tree::SearchTree) = length(tree.nodes)


"""
    TreeSearchRuntimeData

    Data used by the tree search algorithm while running.
    Destroyed after each run.     
"""
mutable struct TreeSearchRuntimeData
    primary_tree::SearchTree
    max_primary_tree_size::Int64
    secondary_tree::SearchTree
    tree_order::Int64
    optstate::OptimizationState
    exploitsprimalsolutions::Bool
    Sense::Type{<:Coluna.AbstractSense}
end

Base.isempty(data::TreeSearchRuntimeData) = isempty(data.primary_tree) && isempty(data.secondary_tree)
primary_tree_is_full(data::TreeSearchRuntimeData) = nb_open_nodes(data.primary_tree) >= data.max_primary_tree_size

function push!(data::TreeSearchRuntimeData, node::Node) 
    if primary_tree_is_full(data) 
        push!(data.secondary_tree, node)
    else           
        push!(data.primary_tree, node)
    end
end

function popnode!(data::TreeSearchRuntimeData)::Node
    if isempty(data.secondary_tree)
        return popnode!(data.primary_tree)
    end
    return popnode!(data.secondary_tree)
end

function nb_open_nodes(data::TreeSearchRuntimeData)
    return nb_open_nodes(data.primary_tree) + nb_open_nodes(data.secondary_tree)
end
get_tree_order(data::TreeSearchRuntimeData) = data.tree_order
getoptstate(data::TreeSearchRuntimeData) = data.optstate

"""
    TreeSearchAlgorithm

    This algorithm uses search tree to do optimization. At each node in the tree, we apply
    conquer algorithm to improve the bounds and divide algorithm to generate child nodes.
"""
Base.@kwdef struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColGenConquer()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000 
    opennodeslimit::Int64 = 100 
    skiprootnodeconquer = false # true for diving heuristics
    rootpriority = 0
    nontrootpriority = 0
    storelpsolution = false 
end

function getslavealgorithms!(
    algo::TreeSearchAlgorithm, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}
)
    push!(slaves, (reform, typeof(algo.conqueralg)))
    getslavealgorithms!(algo.conqueralg, reform, slaves)
    push!(slaves, (reform, typeof(algo.dividealg)))
    getslavealgorithms!(algo.dividealg, reform, slaves)
end


function print_node_info_before_conquer(data::TreeSearchRuntimeData, node::Node)
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
    @printf " time = %.2f sec.\n" Coluna._elapsed_solve_time()

    branch = getbranch(node)
    if node.branchdescription != ""
        println("**** Branching constraint: ", node.branchdescription)
    end
    println("***************************************************************************************")
    return
end

function prepare_and_run_conquer_algorithm!(
    algo::TreeSearchAlgorithm, data::TreeSearchRuntimeData,
    reform::Reformulation, node::Node
)
    if (!node.conquerwasrun)
        set_tree_order!(node, data.tree_order)
        data.tree_order += 1
    end
    
    print_node_info_before_conquer(data, node)

    node.conquerwasrun && return

    treestate = getoptstate(data)
    nodestate = getoptstate(node)
    update_ip_primal!(nodestate, treestate, data.exploitsprimalsolutions)

    apply_conquer_alg_to_node!(node, algo.conqueralg, reform)        

    update_all_ip_primal_solutions!(treestate, nodestate)
    
    if algo.storelpsolution && isrootnode(node) && nb_lp_primal_sols(nodestate) > 0
        set_lp_primal_sol!(treestate, deepcopy(get_best_lp_primal_sol(nodestate))) 
    end 
end

function update_tree!(data::TreeSearchRuntimeData, output::DivideOutput)
end

function prepare_and_run_divide_algorithm!(
    algo::TreeSearchAlgorithm, data::TreeSearchRuntimeData, 
    reform::Reformulation, node::Node
)
    if to_be_pruned(node)
        println("Node is already conquered. No children will be generated")
        return
    end        

    storage = getstorage(reform, getstoragetype(typeof(algo)))
    prepare!(storage, node.dividerecord)
    node.dividerecord = nothing

    treestate = getoptstate(data)
    output = run!(algo.dividealg, reform, DivideInput(node, treestate))

    update_all_ip_primal_solutions!(treestate, getoptstate(output))

    @logmsg LogLevel(-1) string("Updating tree.")

    isempty(getchildren(output)) && return

    print("Child nodes generated :")

    for child in getchildren(output)
        if (child.conquerwasrun)
            set_tree_order!(child, data.tree_order)
            data.tree_order += 1
            print(" N° ", get_tree_order(child) ," ")
        end
        push!(data, child)
    end
    println()
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
    set_ip_dual_bound!(treestate, worst_bound)

    return
end

# TODO : make it better
function determine_statuses(data::TreeSearchRuntimeData)
    fully_explored = isempty(data)
    treestate = getoptstate(data)
    found_sols = (nb_ip_primal_sols(treestate) > 0)
    gap_is_zero = (get_ip_primal_bound(treestate) / get_ip_dual_bound(treestate) ≈ 1.0)
    #gap_is_zero && @assert found_sols
    found_sols && setfeasibilitystatus!(treestate, FEASIBLE)
    gap_is_zero && setterminationstatus!(treestate, OPTIMAL)
    if !found_sols # Implies that gap is not zero
        setterminationstatus!(treestate, EMPTY_RESULT)
        # Determine if we can prove that is was infeasible
        if fully_explored
            setfeasibilitystatus!(treestate, INFEASIBLE)
        else
            setfeasibilitystatus!(treestate, UNKNOWN_FEASIBILITY)
        end
    elseif !gap_is_zero
        setterminationstatus!(treestate, OTHER_LIMIT)
    end
end    

function TreeSearchRuntimeData(algo::TreeSearchAlgorithm, reform::Reformulation, input::OptimizationInput)
    exploitsprimalsols = exploits_primal_solutions(algo.conqueralg) || exploits_primal_solutions(algo.dividealg)        
    treestate = CopyBoundsAndStatusesFromOptState(getmaster(reform), getoptstate(input), exploitsprimalsols)
    data = TreeSearchRuntimeData(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()), 1,
        treestate, exploitsprimalsols, getobjsense(reform)
    )
    push!(data, RootNode(getmaster(reform), treestate, algo.skiprootnodeconquer))
    return data
end

function run!(algo::TreeSearchAlgorithm, reform::Reformulation, input::OptimizationInput)::OptimizationOutput
    
    data = TreeSearchRuntimeData(algo, reform, input)

    while (!isempty(data) && get_tree_order(data) <= algo.maxnumnodes)
        node = popnode!(data)
    
        prepare_and_run_conquer_algorithm!(algo, data, reform, node)      

        prepare_and_run_divide_algorithm!(algo, data, reform, node)
        
        updatedualbound!(data)
        
        # we delete solutions from the node optimization state, as they are not needed anymore
        clear_solutions!(getoptstate(node))
    end

    determine_statuses(data)
    return OptimizationOutput(getoptstate(data))
end

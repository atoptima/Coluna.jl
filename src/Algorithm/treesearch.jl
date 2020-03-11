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
    result::OptimizationResult
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
getresult(data::TreeSearchRuntimeData) = data.result

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

    db = getvalue(get_ip_dual_bound(getresult(data)))
    pb = getvalue(get_ip_primal_bound(getresult(data)))
    node_db = getvalue(get_ip_dual_bound(getincumbents(node)))
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
    data::TreeSearchRuntimeData, algo::AbstractConquerAlgorithm, 
    reform::Reformulation, node::Node, store_lp_solution::Bool
)
    if (!node.conquerwasrun)
        set_tree_order!(node, data.tree_order)
        data.tree_order += 1
    end

    print_node_info_before_conquer(data, node)

    node.conquerwasrun && return 

    @logmsg LogLevel(0) string("Setting up node ", data.tree_order, " before apply")

    optoutput = apply_conquer_alg_to_node!(node, algo, reform, getresult(data))        

    if isrootnode(node) && store_lp_solution
        treesearchresult = getresult(data)
        set_lp_dual_bound(treesearchresult, get_lp_dual_bound(optoutput))
        set_lp_primal_sol(treesearchresult, get_lp_primal_sol(optoutput)) 
    end 
end

function update_tree!(data::TreeSearchRuntimeData, output::DivideOutput)
    @logmsg LogLevel(0) string("Updating tree.")

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

function prepare_and_run_divide_algorithm!(
    data::TreeSearchRuntimeData, algo::AbstractDivideAlgorithm, 
    reform::Reformulation, node::Node
)
    if to_be_pruned(node, get_ip_primal_bound(getresult(data)))
        println("Node is already conquered. No children will be generated")
        return
    end        

    storage = getstorage(reform, getstoragetype(typeof(algo)))
    prepare!(storage, node.dividerecord)
    node.dividerecord = nothing

    output = run!(algo, reform, DivideInput(node, get_ip_primal_bound(getresult(data))))
    
    update_tree!(data, output)

    if nb_ip_primal_sols(getresult(output)) > 0
        for primal_sol in get_ip_primal_sols(getresult(output))
            add_ip_primal_sol!(getresult(data), deepcopy(primal_sol))
        end
    end
end

function updatedualbound!(data::TreeSearchRuntimeData)
    result = getresult(data)
    bound_value = getvalue(get_ip_primal_bound(result))

    worst_bound = DualBound{data.Sense}(bound_value)  
    for (node, priority) in getnodes(data.primary_tree)
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for (node, priority) in getnodes(data.secondary_tree)
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    set_ip_dual_bound!(result, worst_bound)
    return
end

function run!(algo::TreeSearchAlgorithm, reform::Reformulation, input::NewOptimizationInput)::OptimizationOutput
    initresult = getinputresult(input)

    res = OptimizationResult(getmaster(reform), initresult)

    data = TreeSearchRuntimeData(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()), 0,
        res, getobjsense(reform)
    )
    push!(data, RootNode(res, algo.skiprootnodeconquer))
    data.tree_order += 1

    while (!isempty(data) && get_tree_order(data) <= algo.maxnumnodes)
        cur_node = popnode!(data)

        prepare_and_run_conquer_algorithm!(
            data, algo.conqueralg, reform, cur_node, algo.storelpsolution
        )      
        
        prepare_and_run_divide_algorithm!(
            data, algo.dividealg, reform, cur_node
        )
        
        updatedualbound!(data)
    end

    #determine_statuses(getresult(data), isempty(data))
    # TODO : make it better
    fully_explored = isempty(data)
    found_sols = (nb_ip_primal_sols(res) > 0)
    #res = getresult(data)
    gap_is_zero = (get_ip_primal_bound(res) / get_ip_dual_bound(res) ≈ 1.0)
    # We assume that gap cannot be zero if no solution was found
    gap_is_zero && @assert found_sols
    found_sols && setfeasibilitystatus!(res, FEASIBLE)
    gap_is_zero && setterminationstatus!(res, OPTIMAL)
    if !found_sols # Implies that gap is not zero
        setterminationstatus!(res, EMPTY_RESULT)
        # Determine if we can prove that is was infeasible
        if fully_explored
            setfeasibilitystatus!(res, INFEASIBLE)
        else
            setfeasibilitystatus!(res, UNKNOWN_FEASIBILITY)
        end
    elseif !gap_is_zero
        setterminationstatus!(res, OTHER_LIMIT)
    end
    # end TODO
    return OptimizationOutput(res)
end

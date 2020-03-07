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
    output::OptimizationOutput
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

nb_open_nodes(data::TreeSearchRuntimeData) = (nb_open_nodes(data.primary_tree)
                                       + nb_open_nodes(data.secondary_tree))
get_tree_order(data::TreeSearchRuntimeData) = data.tree_order

getoutput(data::TreeSearchRuntimeData) = data.output
getresult(data::TreeSearchRuntimeData) = getresult(data.output)

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

    db = getvalue(getdualbound(getresult(data)))
    pb = getvalue(getprimalbound(getresult(data)))
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

    println("\e[31m ")
    @show get_lp_primal_sol(optoutput)
    println("\e[00m")
    @show isrootnode(node)
    @show store_lp_solution
    if isrootnode(node) && store_lp_solution
        treesearchoutput = getoutput(data)
        set_lp_dual_bound(treesearchoutput, get_lp_dual_bound(optoutput))
        set_lp_primal_sol(treesearchoutput, get_lp_primal_sol(optoutput)) 
        @show get_lp_primal_sol(treesearchoutput)  
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
    if to_be_pruned(node, getprimalbound(getresult(data)))
        println("Node is already conquered. No children will be generated")
        return
    end        

    storage = getstorage(reform, getstoragetype(typeof(algo)))
    prepare!(storage, node.dividerecord)
    node.dividerecord = nothing

    output = run!(algo, reform, DivideInput(node, getprimalbound(getresult(data))))
    
    update_tree!(data, output)

    for primal_sol in getprimalsols(getresult(output))
        add_primal_sol!(getresult(data), deepcopy(primal_sol))
    end
end

function updatedualbound!(data::TreeSearchRuntimeData)
    result = getresult(data)
    bound_value = getvalue(getprimalbound(result))
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
    setdualbound!(result, worst_bound)
    return
end

function run!(algo::TreeSearchAlgorithm, reform::Reformulation, input::OptimizationInput)::OptimizationOutput

    initincumb = getincumbents(input)
    data = TreeSearchRuntimeData(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()), 0,
        OptimizationOutput(getmaster(reform), initincumb), getobjsense(reform)
    )
    push!(data, RootNode(initincumb,algo.skiprootnodeconquer))
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

    determine_statuses(getresult(data), isempty(data))
    return getoutput(data)
end

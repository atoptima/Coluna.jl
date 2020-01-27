using ..Coluna # to remove when merging to the master branch


"""
    AbstractConquerOutput

    Output of a conquer algorithm used by the tree search algorithm.
    Should contain current incumbents, infeasibility status, and the record of its storage.
"""
abstract type AbstractConquerOutput <: AbstractOutput end

function getincumbents(output::AbstractConquerOutput)::Incumbents end
function getrecord(output::AbstractConquerOutput)::AbstractConquerRecord end
function getinfeasible(output::AbstractConquerOutput)::Bool end


"""
    AbstractConquerAlgorithm

    This algorithm type is used by the tree search algorithm to update the incumbents and the formulation.
    Input of this algorithm is current incumbents    
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end

function run!(algo::AbstractConquerAlgorithm, reform::Reformulation, incumb::Incumbents)::AbstractConquerOutput
    algotype = typeof(algo)
    error("Method run! which takes Reformulation and Incumbents as parameters and returns AbstractConquerOutput 
           is not implemented for algorithm $algotype.")
end    

"""
    AbstractDivideStorage

    Storage of a divide algorithm used by the tree search algorithm.
    Should receive the node to divide.    
"""
abstract type AbstractDivideStorage <: AbstractStorage end

function setnode!(storage::AbstractDivideStorage, node::Node) end

"""
    AbstractDivideOutput

    Output of a divide algorithm used by the tree search algorithm.
    Should contain the vector of generated nodes.
"""
abstract type AbstractDivideOutput <: AbstractOutput end

function getchildren(output::AbstractDivideOutput)::Vector{Node} end

"""
    AbstractDivideAlgorithm

    This algoirthm type is used by the tree search algorithm to generate nodes.
"""
abstract type AbstractDivideAlgorithm <: AbstractAlgorithm end

function run!(algo::AbstractDivideAlgorithm, reform::Reformulation, node::Node)::AbstractDivideOutput
    algotype = typeof(algo)
    error("Method run! which takes Reformulation and Node as parameters and returns AbstractDivideOutput 
           is not implemented for algorithm $algotype.")
end    


"""
    SearchTree
"""
mutable struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    strategy::AbstractTreeExploreStrategy
end

SearchTree(strategy::AbstractTreeExploreStrategy) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), strategy, true
)

getnodes(tree::SearchTree) = tree.nodes
Base.isempty(tree::SearchTree) = isempty(tree.nodes)

push!(tree::SearchTree, node::Node) = DS.enqueue!(tree.nodes, node, getvalue(tree.explore_strategy, node))
popnode!(tree::SearchTree) = DS.dequeue!(tree.nodes)
nb_open_nodes(tree::SearchTree) = length(tree.nodes)


"""
    TreeSearchData

    Data used by the tree search algorithm.
    Note that it is not a storage. It is initialized
    every time the tree search algorithm is run. 
    It is destroyed every time the tree search algorithm
    is finished.   
"""
mutable struct TreeSearchData
    primary_tree::SearchTree
    max_primary_tree_size::Int64
    secondary_tree::SearchTree
    tree_order::Int64
    result::OptimizationResult
end

Base.isempty(data::TreeSearchData) = isempty(data.primary_tree) && isempty(data.secondary_tree)
primary_tree_is_full(data::TreeSearchData) = nb_open_nodes(data.primary_tree) >= data.max_primary_tree_size

function push!(data::TreeSearchData, node::Node) 
    if primary_tree_is_full(s) 
        push!(data.secondary_tree, node)
    else           
        push!(data.primary_tree, node)
    end
end

function popnode!(data::TreeSearchData)::Node
    if isempty(data.secondary_tree)
        return popnode!(data.primary_tree)
    end
    return popnode!(data.secondary_tree)
end

nb_open_nodes(data::TreeSearchData) = (nb_open_nodes(data.primary_tree)
                                       + nb_open_nodes(data.secondary_tree))
get_tree_order(data::TreeSearchData) = data.tree_order

getresult(data::TreeSearchData) = data.result

"""
    TreeSearchAlgorithm

    This algorithm uses search tree to do optimization. At each node in the tree, we apply
    conquer algorithm to improve the bounds and divide algorithm to generate child nodes.
"""
Base.@kwdef struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColAndCutGenAlgorithm()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000 
    opennodeslimit::Int64 = 100 
end

# storage of the tree search algorithm is empty for the moment
getstoragetype(algo::TreeSearchAlgorithm) = EmptyStorage

function getslavealgorithms!(
    algo::TreeSearchAlgorithm, reform::Reformulation, 
    slaves::Vector{Tuple{AbstractFormulation, Type{<:AbstractAlgorithm}}}
    )
    push!(slaves, (reform, typeof(algo.conqueralg)))
    push!(slaves, (reform, typeof(algo.dividealg)))
end

function print_node_info_before_conquer(data::TreeSearchData, node::Node)
    println("************************************************************")
    print(nb_open_nodes(data) + 1)
    println(" open nodes.")
    if !node.conquerwasrun
        print("Node ", get_tree_order(node), " is conquered, no need to treat. ")
    else    
        print("Treating node ", get_tree_order(data), ". ")
    end
    getparent(node) === nothing && println()
    getparent(node) !== nothing && println("Parent is ", get_tree_order(getparent(node)))

    node_incumbents = getincumbents(node)
    db = getdualbound(getresult(data))
    pb = getprimalbound(getresult(data))
    node_db = get_ip_dual_bound(node_incumbents)

    print("Current best known bounds : ")
    printbounds(db, pb)
    println()
    @printf "Elapsed time: %.2f seconds\n" Coluna._elapsed_solve_time()
    println("Subtree dual bound is ", node_db)

    branch = getbranch(node)
    if node.branchdescription != ""
        println("Branching constraint: ", node.branchdescription)
    end
    println("************************************************************")
    return
end

function print_info_after_divide(node::Node, output::AbstractDivideOutput)
    println("************************************************************")
    println("Node ", get_tree_order(node), " is treated")
    println("Generated ", length(getchildren(output)), " children nodes")

    node_incumbents = getincumbents(node)
    db = get_ip_dual_bound(node_incumbents)
    pb = get_ip_primal_bound(node_incumbents)

    print("Node bounds after treatment : ")
    printbounds(db, pb)
    println()

    println("************************************************************")
    return
end


# returns true if the conquer algorithm should be run 
function prepare_conqueralg!(data::TreeSearchData, node::Node, cstorage::AbstractStorage)::Bool

    node.conquerwasrun && return false

    @logmsg LogLevel(0) string("Setting up node ", data.tree_order, " before apply")
    set_tree_order!(node, data.tree_order)
    data.tree_order += 1
    if nbprimalsols(data.result) >= 1 
        update_ip_primal_sol!(getincumbents(node), unsafe_getbestprimalsol(data.result))
    end
    @logmsg LogLevel(-1) string("Node IP DB: ", get_ip_dual_bound(getincumbents(node)))
    @logmsg LogLevel(-1) string("Tree IP PB: ", get_ip_primal_bound(getincumbents(node)))
    if (ip_gap(getincumbents(node)) <= 0.0 + 0.00000001)
        @logmsg LogLevel(-1) string("IP Gap is non-positive: ", ip_gap(getincumbents(node)), ". Abort treatment.")
        return false
    end
    @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")

    prepare!(cstorage, node.conquerrecord)    
    node.conquerrecord = nothing

    return true
end

function update_tree!(data::TreeSearchData, output::AbstractDivideOutput)
    @logmsg LogLevel(0) string("Updating tree.")

    @logmsg LogLevel(-1) string("Inserting ", length(output.children), " children nodes in tree.")
    for child in getchildren(output)
        if (child.conquerwasrun)
            set_tree_order!(child, data.tree_order)
            data.tree_order += 1
        end
        push!(data, child)
    end
    return
end

function updatedualbound!(data::TreeSearchData, cur_node::Node)
    result = getresult(data)
    worst_bound = get_ip_dual_bound(getincumbents(cur_node))
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

function run!(algo::TreeSearchAlgorithm, reform::Reformulation, incumb::Incumbents)::OptimizationResult

    conquerstorage = getstorage(reform, getstoragetype(algo.conqueralg))
    dividestorage = getstorage(reform, getstoragetype(algo.dividealg))

    data = TreeSearchData(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()), 0,
        OptimizationResult(incumb)
    )
    push!(data, RootNode(
        getrootrecord(conquerstorage), getrootrecord(dividestorage), reform.master.obj_sense
        )
    )
    data.tree_order += 1

    while (!isempty(data) && get_tree_order(data) <= algo.maxnumnodes)

        cur_node = popnode!(data)
        print_node_info_before_conquer(data, cur_node)
        if prepare_conqueralg!(data, cur_node, conquerstorage)

            conqueroutput = run!(algo.conqueralg, reform, getincumbents(cur_node))
            update!(getincumbents(cur_node), getincumbents(conqueroutput))
            if isbetter(get_ip_primal_bound(getincumbents(cur_node)), getprimalbound(getresult(data)))
                add_primal_sol!(getresult(data), deepcopy(get_ip_primal_sol(getincumbents(cur_node))))
            end        
            getinfeasible(conqueroutput) && setinfeasible(cur_node)
            !to_be_pruned(cur_node) && cur_node.conquerrecord = getrecord(conqueroutput)
        end
        if !to_be_pruned(cur_node)
            prepare!(dividestorage, cur_node.dividerecord)
            cur_node.dividerecord = nothing
            divideoutput = run!(algo.dividealg, reform, cur_node)
            print_info_after_divide(data, cur_node, divideoutput)
            update_tree!(data, divideoutput)
        end            

        updatedualbound!(data, cur_node)
    end

    determine_statuses(getresult(data), isempty(data))
    return getresult(data)
end

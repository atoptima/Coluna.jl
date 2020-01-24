using ..Coluna # to remove when merging to the master branch


"""
    AbstractConquerStorage

    Storage of a conquer algorithm used by the tree search algorithm.
    Should receive reformulation on its construction.
    Should receive the current incumbents before running the conquer algorithm.
"""
abstract type AbstractConquerStorage <: AbstractStorage end

function setincumbents!(storage::AbstractConquerStorage, bound::Incumbents) end


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

    This algoirthm type is used by the tree search algorithm to update the incumbents and the formulation.
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end

function run!(algo::AbstractConquerAlgorithm, storage::AbstractConquerStorage)::AbstractConquerOutput
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
abstract type AbstractDivideOutput <: AbstractConquerOutput end

function getchildren(output::AbstractDivideOutput)::Vector{Node} end

"""
    AbstractDivideAlgorithm

    This algoirthm type is used by the tree search algorithm to generate nodes.
"""
abstract type AbstractDivideAlgorithm <: AbstractAlgorithm end


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
    TreeSearchStorage

    Storage of TreeSearchAlgorithm
"""
mutable struct TreeSearchStorage <: AbstractStorage
    reform::Reformulation
    primary_tree::SearchTree
    max_primary_tree_size::Int64
    secondary_tree::SearchTree
    tree_order::Int64
    conquerstorage::AbstractStorage
    dividestorage::AbstractStorage
    result::OptimizationResult
end

Base.isempty(s::TreeSearchStorage) = isempty(s.primary_tree) && isempty(s.secondary_tree)
primary_tree_is_full(s::TreeSearchStorage) = nb_open_nodes(s.primary_tree) >= s.max_primary_tree_size

function push!(s::TreeSearchStorage, node::Node) 
    if primary_tree_is_full(s) 
        push!(s.secondary_tree, node)
    else           
        push!(s.primary_tree, node)
    end
end

function popnode!(s::TreeSearchStorage)::Node
    if isempty(s.secondary_tree)
        return popnode!(s.primary_tree)
    end
    return popnode!(s.secondary_tree)
end

nb_open_nodes(s::TreeSearchStorage) = (nb_open_nodes(s.primary_tree)
                                       + nb_open_nodes(s.secondary_tree))
get_tree_order(s::TreeSearchStorage) = s.tree_order
getresult(s::TreeSearchStorage) = s.result

"""
    TreeSearchAlgorithm

    This algorithm uses search tree to do optimization. At each node in the tree, we apply
    conquer algorithm to improve the bounds and divide algorithm to generate child nodes.
"""
Base.@kwdef struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = DefaultConquerAlgorithm()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000 
    opennodeslimit::Int64 = 100 
end

function construct(algo::TreeSearchAlgorithm, reform::Reformulation)::TreeSearchStorage
    ObjSense = reform.master.obj_sense
    return TreeSearchStorage( 
        reform, SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()), 
        0, true, construct(algo.conqueralg, reform), construct(algo.dividealg, reform), 
        OptimizationResult{ObjSense}()
    )
end

function print_node_info_before_conquer(storage::TreeSearchStorage, node::Node)
    println("************************************************************")
    print(nb_open_nodes(storage) + 1)
    println(" open nodes.")
    if !node.conquerwasrun
        print("Node ", get_tree_order(node), " is conquered, no need to treat. ")
    else    
        print("Treating node ", get_tree_order(storage), ". ")
    end
    getparent(node) === nothing && println()
    getparent(node) !== nothing && println("Parent is ", get_tree_order(getparent(node)))

    node_incumbents = getincumbents(node)
    db = getdualbound(getresult(storage))
    pb = getprimalbound(getresult(storage))
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

function print_info_after_divide(storage::TreeSearchStorage, node::Node, output::AbstractDivideOutput)
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
function prepare_conqueralg!(storage::TreeSearchStorage, node::Node)::Bool

    node.conquerwasrun && return false

    @logmsg LogLevel(0) string("Setting up node ", storage.tree_order, " before apply")
    set_tree_order!(node, storage.tree_order)
    storage.tree_order += 1
    if nbprimalsols(storage.result) >= 1 
        update_ip_primal_sol!(getincumbents(node), unsafe_getbestprimalsol(storage.result))
    end
    @logmsg LogLevel(-1) string("Node IP DB: ", get_ip_dual_bound(getincumbents(node)))
    @logmsg LogLevel(-1) string("Tree IP PB: ", get_ip_primal_bound(getincumbents(node)))
    if (ip_gap(getincumbents(node)) <= 0.0 + 0.00000001)
        @logmsg LogLevel(-1) string("IP Gap is non-positive: ", ip_gap(getincumbents(node)), ". Abort treatment.")
        return false
    end
    @logmsg LogLevel(-1) string("IP Gap is positive. Need to treat node.")

    prepare!(storage.conquerstorage, node.conquerrecord)    
    node.conquerrecord = nothing
    setincumbents!(storage.conquerstorage, getincumbents(node))

    return true
end

# returns true if the conquer algorithm should be run 
function prepare_dividealg!(storage::TreeSearchStorage, node::Node)
    prepare!(storage.dividestorage, node.dividerecord)
    node.dividerecord = nothing
    setnode!(storage.dividestorage, node)    
end

function update_tree!(storage::TreeSearchStorage, output::AbstractDivideOutput)
    @logmsg LogLevel(0) string("Updating tree.")

    @logmsg LogLevel(-1) string("Inserting ", length(output.children), " children nodes in tree.")
    for child in getchildren(output)
        if (child.conquerwasrun)
            set_tree_order!(child, storage.tree_order)
            storage.tree_order += 1
        end
        push!(storage, child)
    end
    return
end

function updatedualbound!(storage::TreeSearchStorage, cur_node::Node)
    result = getresult(storage)
    worst_bound = get_ip_dual_bound(getincumbents(cur_node))
    for (node, priority) in getnodes(storage.primary_tree)
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for (node, priority) in getnodes(storage.secondary_tree)
        db = get_ip_dual_bound(getincumbents(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    setdualbound!(result, worst_bound)
    return
end

function run!(algo::TreeSearchAlgorithm, storage::TreeSearchStorage)::OptimizationResult

    reform = storage.reform
    conquerstorage = storage.conquerstorage
    dividestorage = storage.dividestorage

    push!(storage, RootNode(
        getrootrecord(conquerstorage), getrootrecord(dividestorage), reform.master.obj_sense
        )
    )
    storage.tree_order += 1

    while (!isempty(storage) && get_tree_order(storage) <= algo.maxnumnodes)

        cur_node = popnode!(storage)
        print_node_info_before_conquer(storage, cur_node)
        if prepare_conqueralg!(storage, cur_node)

            coutput = run!(algo.conqueralg, conquerstorage)
            update!(getincumbents(cur_node), getincumbents(coutput))
            if isbetter(get_ip_primal_bound(getincumbents(cur_node)), getprimalbound(getresult(storage)))
                add_primal_sol!(getresult(storage), deepcopy(get_ip_primal_sol(getincumbents(cur_node))))
            end        
            getinfeasible(coutput) && setinfeasible(cur_node)
            !to_be_pruned(cur_node) && cur_node.conquerrecord = getrecord(coutput)
        end
        if !to_be_pruned(cur_node)
            prepare_dividealg!(storage, cur_node)
            doutput = run!(algo.dividealg, dividestorage)
            print_info_after_divide(storage, cur_node, doutput)
            update_tree!(storage, doutput)
        end            

        updatedualbound!(storage, cur_node)
    end

    determine_statuses(getresult(storage), isempty(storage))
    return getresult(storage)
end

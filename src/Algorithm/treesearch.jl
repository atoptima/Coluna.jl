using ..Coluna # to remove when merging to the master branch

"""
    AbstractRecord

Record is a used to recover the state of a storage or a formulation in a different node of a search tree
"""
abstract type AbstractRecord end

struct EmptyRecord <: AbstractRecord end

"""
    setup!(Storage, Record)

This function recovers the state of Storage using Record    
"""
function setup(storage::AbstractStorage, record::AbstractRecord) end

"""
    record(Storage)::Record

This function records the state of Storage to Record. By default, the record is empty.
"""
function record(storage::AbstractStorage)::AbstractRecord
    return EmptyRecord()
end 


"""
    AbstractConquerAlgorithm

    This algoirthm type is used by the tree search algorithm to update the incumbents and the formulation.
"""
abstract type AbstractConquerAlgorithm <: AbstractAlgorithm end


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
    fully_explored::Bool
end

SearchTree(strategy::AbstractTreeExploreStrategy) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), strategy, true
)

getnodes(tree::SearchTree) = tree.nodes
Base.isempty(tree::SearchTree) = isempty(tree.nodes)

push!(tree::SearchTree, node::Node) = DS.enqueue!(tree.nodes, node, getvalue(tree.explore_strategy, node))
popnode!(tree::SearchTree) = DS.dequeue!(tree.nodes)
nb_open_nodes(tree::SearchTree) = length(tree.nodes)
was_fully_explored(tree::SearchTree) = tree.fully_explored


"""
    TreeSearchStorage

    Storage of TreeSearchAlgorithm
"""
mutable struct TreeSearchStorage <: AbstractStorage
    reform::Reformulation
    primary_tree::SearchTree
    secondary_tree::SearchTree
    conquerstorage::AbstractStorage
    dividestorage::AbstractStorage
end

"""
    TreeSearchAlgorithm

    This algorithm uses search tree to do optimization. At each node in the tree, we apply
    conquer algorithm to improve the bounds and divide algorithm to generate child nodes.
"""
struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm
    dividealg::AbstractDivideAlgorithm
    explorestrategy::AbstractTreeExploreStrategy
end

function construct(algo::TreeSearchAlgorithm, reform::Reformulation)::TreeSearchStorage
    return TreeSearchStorage( 
        reform, SearchTree(algo.explorestrategy), SearchTree(DepthFirstStrategy()),
        construct(algo.conqueralg, reform), construct(algo.dividealg, reform)
    )
end

# stopped here OptimizationResult should be renamed to OptimizationOutput <: AbstractOutput

function run!(algo::TreeSearchAlgorithm, storage::TreeSearchStorage)::AbstractOutput
    return EmptyOutput()
end


# This module provide an interface to implement tree search algorithms and default
# implementations of the tree search algorithm for some explore strategies.
module TreeSearch

using DataStructures

!true && include("../MustImplement/MustImplement.jl") # linter
using ..MustImplement

!true && include("../interface.jl") # linter
using ..AlgoAPI

# Interface to implement a tree search algorithm.
"""
Contains the definition of the problem tackled by the tree search algorithm and how the
nodes and transitions of the tree search space will be explored.
"""
abstract type AbstractSearchSpace end

"Algorithm that chooses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end

# The definition of a tree search algorithm is based on three concepts.
"Returns the type of search space depending on the tree-search algorithm and its parameters."
@mustimplement "TreeSearch" search_space_type(::AlgoAPI.AbstractAlgorithm) = nothing

"Creates and returns the search space of a tree search algorithm, its model, and its input."
@mustimplement "TreeSearch"  new_space(::Type{<:AbstractSearchSpace}, alg, model, input) = nothing

"Creates and returns the root node of a search space."
@mustimplement "TreeSearch" new_root(::AbstractSearchSpace, input) = nothing

"Returns the root node of the tree to which the node belongs."
@mustimplement "Node" get_root(::AbstractNode) = nothing

"Returns the parent of a node; `nothing` if the node is the root."
@mustimplement "Node" get_parent(::AbstractNode) = nothing

"Returns the priority of the node depending on the explore strategy."
@mustimplement "Node" get_priority(::AbstractExploreStrategy, ::AbstractNode) = nothing

##### Additional methods for the node interface (needed by conquer)
## TODO: move outside TreeSearch module.
@mustimplement "Node" set_records!(::AbstractNode, records) = nothing

"Returns a `String` to display the branching constraint."
@mustimplement "Node" get_branch_description(::AbstractNode) = nothing # printer

"Returns `true` is the node is root; `false` otherwise."
@mustimplement "Node" isroot(::AbstractNode) = nothing # BaB implementation

# TODO: remove untreated nodes.
"Evaluate and generate children. This method has a specific implementation for Coluna."
@mustimplement "TreeSearch" children(sp, n, env, untreated_nodes) = nothing

"Returns true if stopping criteria are met; false otherwise."
@mustimplement "TreeSearch" stop(::AbstractSearchSpace, untreated_nodes) = nothing

# TODO: remove untreated nodes.
"Returns the output of the tree search algorithm."
@mustimplement "TreeSearch" tree_search_output(::AbstractSearchSpace, untreated_nodes) = nothing

# Default implementations for some explore strategies.
include("explore.jl")

end
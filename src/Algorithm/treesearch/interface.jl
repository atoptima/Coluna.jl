# The definition of a tree search algorithm is based on four concepts.

"Definition of the problem tackled by the tree seach algorithm."
abstract type AbstractSearchSpace end

"Algorithm that chosses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end

"""
AbstractTracker implements an interface with methods to:
- save data at a given node
- get data at a given node
- compute data to activate / deactivate in order to restore the searchspace 
  to move from a node to another node.
"""
abstract type AbstractTracker end

# Interface to implement
"Creates and returns the root node of a search space."
new_root(::AbstractSearchSpace, ::AbstractTracker) = nothing

"Creates and returns the children of a node associated to a search space."
new_children(::AbstractExploreStrategy, node, space, tracker) = nothing

"Returns the id of a node."
uid(::AbstractNode) = nothing

"Returns the root node of the tree to which the node belongs."
root(::AbstractNode) = nothing

"Returns the parent of a node; nothing if the node is the root."
parent(::AbstractNode) = nothing

"Returns an array that contains children of the node."
children(::AbstractNode) = nothing

"Deletes a node and the associated information in the tracker."
delete_node(::AbstractNode, ::AbstractTracker) = nothing

"Returns the manager which is responsible for handling the kpis and the best know solution."
manager(::AbstractSearchSpace) = nothing

cost(::AbstractExploreStrategy, ::AbstractNode) = nothing

# Composition pattern
"Returns the inner space of search space; nothing if no composition."
inner_space(::AbstractSearchSpace) = nothing


# Methods specific to the tracker

"A data structure that wraps a piece of information to track in the tree."
abstract type AbstractTrackedData end

new_tracker(::AbstractExploreStrategy, ::AbstractSearchSpace) = nothing

"Save a piece of information in the tracker for a given node."
save!(::AbstractTracker, ::AbstractNode, ::AbstractTrackedData) = nothing

"Returns a piece of information from the tracker for a given node."
Base.get(::AbstractTracker, ::AbstractNode, ::Type{AbstractTrackedData}) = nothing

"""
Computes data to activate / deactivate information in order to restore the searchspace 
to move from a node to another node.
"""
diff(::AbstractTracker, src::AbstractNode, dest::AbstractNode, ::Type{AbstractTrackedData}) = nothing

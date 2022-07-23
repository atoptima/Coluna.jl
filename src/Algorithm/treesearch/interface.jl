# The definition of a tree search algorithm is based on four concepts.

"Contains the definition of the problem tackled by the tree search algorithm."
abstract type AbstractSearchSpace end

"Algorithm that chooses next node to evaluated in the tree search algorithm."
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
function new_children(candidates, a::AbstractAlgorithm, n::AbstractNode, sp::AbstractSearchSpace, t::AbstractTracker)
  @warn "new_children($(typeof(candidates)), $(typeof(a)), $(typeof(n)), $(typeof(sp)), $(typeof(t))) not implemented."
  return nothing
end

"Returns the id of a node."
uid(::AbstractNode) = nothing

"Returns the root node of the tree to which the node belongs."
root(::AbstractNode) = nothing

"Returns the parent of a node; nothing if the node is the root."
parent(::AbstractNode) = nothing

"Returns the manager which is responsible for handling the kpis and the best know solution."
manager(::AbstractSearchSpace) = nothing

# TODO
cost(::AbstractExploreStrategy, ::AbstractNode) = nothing

# Composition pattern (TO TEST)
"Returns the inner space of search space; nothing if no composition."
inner_space(::AbstractSearchSpace) = nothing

# Methods specific to the tracker

"A data structure that wraps a piece of information to track in the tree."
abstract type AbstractTrackedData end

function new_tracker(st::AbstractExploreStrategy, sp::AbstractSearchSpace)
  @warn "new_tracker(::$(typeof(st)), ::$(typeof(sp))) not implemented."
  return nothing
end

"Save a piece of information in the tracker for a given node."
save!(::AbstractTracker, ::AbstractNode, ::AbstractTrackedData) = nothing

"Returns a piece of information from the tracker for a given node."
Base.get(::AbstractTracker, ::AbstractNode, ::Type{AbstractTrackedData}) = nothing

"""
Computes data to activate / deactivate information in order to restore the searchspace 
to move from a node to another node.
"""
diff(::AbstractTracker, src::AbstractNode, dest::AbstractNode, ::Type{AbstractTrackedData}) = nothing

# Methods specific to the space (this is WIP)
function get_reformulation(a::AbstractAlgorithm, s::AbstractSearchSpace)
  @warn "get_reformulation(::$(typeof(a)), ::$(typeof(s))) not implemented."
  return nothing
end

function get_input(a::AbstractAlgorithm, s::AbstractSearchSpace, n::AbstractNode, t::AbstractTracker)
  @warn "get_input(::$(typeof(a)), ::$(typeof(s)), ::$(typeof(n)), ::$(typeof(t))) not implemented."
  return nothing
end

function node_change!(previous::AbstractNode, current::AbstractNode, space::AbstractSearchSpace, tracker::AbstractTracker)
  @warn "node_change!(::$(typeof(previous)), $(typeof(current)), $(typeof(space)), $(typeof(tracker))) not implemented."
  return nothing
end

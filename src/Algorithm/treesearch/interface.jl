# The definition of a tree search algorithm is based on three concepts.

"Contains the definition of the problem tackled by the tree search algorithm."
abstract type AbstractSearchSpace end

# Follwing methods will be needed in Coluna only (I'll create a specific abstract subspace for Coluna).
function get_reformulation(s::AbstractSearchSpace)
  @warn "get_reformulation(::$(typeof(s))) not implemented."
  return nothing
end

function get_conquer(sp::AbstractSearchSpace)
  @warn "get_conquer(::$(typeof(sp))) not implemented."
  return nothing
end

function get_divide(sp::AbstractSearchSpace)
  @warn "get_divide(::$(typeof(sp))) not implemented."
  return nothing
end

tree_search_output(::AbstractSearchSpace) = nothing

"Algorithm that chooses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end

# Interface to implement
"Returns the type of search space depending on the tree-seach algorithm and its parameters."
search_space_type(::AbstractAlgorithm) = nothing

"Creates and returns the search space of a tree search algorithm, its model, and its input."
function new_space(::Type{SearchSpaceType}, alg, model, input) where SearchSpaceType <: AbstractSearchSpace
  @warn "new_space(::Type{$SearchSpaceType}, ::$(typeof(alg)), ::$(typeof(model)), ::$(typeof(input))) not implemented."
  return nothing
end

"Creates and returns the root node of a search space."
new_root(::AbstractSearchSpace) = nothing

# This method will have a default implementation in Coluna.
"Evaluate and generate children."
function children(sp, n, env)
  @warn "children(::$(typeof(sp)), ::$(typeof(n)), ::$(typeof(env))) not implemented."
  return nothing
end

"Creates and returns the children of a node associated to a search space."
function new_children(sp::AbstractSearchSpace, candidates, n::AbstractNode)
  @warn "new_children(::$(typeof(sp)), ::$(typeof(candidates)), ::$(typeof(n))) not implemented."
  return nothing
end

"Returns the id of a node."
uid(::AbstractNode) = nothing

"Returns the root node of the tree to which the node belongs."
root(::AbstractNode) = nothing

"Returns the parent of a node; nothing if the node is the root."
parent(::AbstractNode) = nothing

# TODO
priority(::AbstractExploreStrategy, ::AbstractNode) = nothing

# TODO: not needed at the moment.
# "Returns the manager which is responsible for handling the kpis and the best know solution."
# manager(::AbstractSearchSpace) = nothing

# TODO: not needed at the moment.
# """
# Computes data to activate / deactivate information in order to restore the searchspace 
# to move from a node to another node.
# """
# diff(::AbstractTracker, src::AbstractNode, dest::AbstractNode) = nothing

# Methods specific to the space (this is WIP)

function get_input(a::AbstractAlgorithm, s::AbstractSearchSpace, n::AbstractNode)
  @warn "get_input(::$(typeof(a)), ::$(typeof(s)), ::$(typeof(n))) not implemented."
  return nothing
end

function node_change!(previous::AbstractNode, current::AbstractNode, space::AbstractSearchSpace)
  @warn "node_change!(::$(typeof(previous)), $(typeof(current)), $(typeof(space))) not implemented."
  return nothing
end

after_conquer!(::AbstractSearchSpace, output) = nothing
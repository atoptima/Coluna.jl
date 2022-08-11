# The definition of a tree search algorithm is based on three concepts.
"""
Contains the definition of the problem tackled by the tree search algorithm and how the
nodes and transitions of the tree search space will be explored.
"""
abstract type AbstractSearchSpace end

"Returns the output of the tree search algorithm."
tree_search_output(::AbstractSearchSpace) = nothing

"Algorithm that chooses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end

"Returns the type of search space depending on the tree-search algorithm and its parameters."
search_space_type(::AbstractAlgorithm) = nothing

"Creates and returns the search space of a tree search algorithm, its model, and its input."
function new_space(::Type{SearchSpaceType}, alg, model, input) where SearchSpaceType <: AbstractSearchSpace
    @warn "new_space(::Type{$SearchSpaceType}, ::$(typeof(alg)), ::$(typeof(model)), ::$(typeof(input))) not implemented."
    return nothing
end

"Creates and returns the root node of a search space."
new_root(::AbstractSearchSpace, input) = nothing

"Evaluate and generate children."
# TODO; remove untreated_nodes
function children(sp, n, env, untreated_nodes)
    @warn "children(::$(typeof(sp)), ::$(typeof(n)), ::$(typeof(env)), untreated_nodes) not implemented."
    return nothing
end

"Returns the root node of the tree to which the node belongs."
root(::AbstractNode) = nothing

"Returns the parent of a node; nothing if the node is the root."
parent(::AbstractNode) = nothing

"Returns the priority of the node."
priority(::AbstractExploreStrategy, ::AbstractNode) = nothing

############################################################################################
# Tree search interface for Coluna algorithms
############################################################################################
abstract type AbstractColunaSearchSpace <: AbstractSearchSpace end

# Additional methods to implement to use the tree search algorithms together with Coluna's
# algorithms.
"Returns the previous node explored by the tree search algorithm."
get_previous(s::AbstractColunaSearchSpace) = nothing

"Sets the previous node explored by the tree search algorithm."
set_previous!(s::AbstractColunaSearchSpace, previous) = nothing

"Returns the conquer algorithm."
function get_conquer(sp::AbstractColunaSearchSpace)
    @warn "get_conquer(::$(typeof(sp))) not implemented."
    return nothing
end

"Returns the divide algorithm."
function get_divide(sp::AbstractColunaSearchSpace)
    @warn "get_divide(::$(typeof(sp))) not implemented."
    return nothing
end

"Returns the reformulation that will be passed to an algorithm."
function get_reformulation(s::AbstractColunaSearchSpace)
    @warn "get_reformulation(::$(typeof(s))) not implemented."
    return nothing
end

"""
Returns the input that will be passed to an algorithm.
The input can be built from information contained in a search space and a node.
"""
function get_input(a::AbstractAlgorithm, s::AbstractColunaSearchSpace, n::AbstractNode)
    @warn "get_input(::$(typeof(a)), ::$(typeof(s)), ::$(typeof(n))) not implemented."
    return nothing
end

"""
Methods to perform operations before the tree search algorithm evaluates a node (`current`).
This is useful to restore the state of the formulation for instance.
"""
function node_change!(previous::AbstractNode, current::AbstractNode, space::AbstractColunaSearchSpace, untreated_nodes)
    @warn "node_change!(::$(typeof(previous)), $(typeof(current)), $(typeof(space)), $(typeof(untreated_nodes))) not implemented."
    return nothing
end

"""
Methods to perform operations after the conquer algorithms.
It receives the output of the conquer algorithm.
"""
after_conquer!(::AbstractColunaSearchSpace, current, output) = nothing

"Creates and returns the children of a node associated to a search space."
function new_children(sp::AbstractColunaSearchSpace, candidates, n::AbstractNode)
    @warn "new_children(::$(typeof(sp)), ::$(typeof(candidates)), ::$(typeof(n))) not implemented."
    return nothing
end

# Implementation of the `children` method for the `AbstractColunaSearchSpace` algorithm.
function children(space::AbstractColunaSearchSpace, current::AbstractNode, env, untreated_nodes)
    # restore state of the formulation for the current node.
    previous = get_previous(space)
    if !isnothing(previous)
        # TODO: it would be nice to remove `untreated_nodes`.
        node_change!(previous, current, space, untreated_nodes)
    end
    set_previous!(space, current)
    # run the conquer algorithm.
    reform = get_reformulation(space)
    conquer_alg = get_conquer(space)
    conquer_input = get_input(conquer_alg, space, current)
    conquer_output = run!(conquer_alg, env, reform, conquer_input)
    after_conquer!(space, current, conquer_output) # callback to do some operations after the conquer.
    # run the divide algorithm.
    divide_alg = get_divide(space)
    divide_input = get_input(divide_alg, space, current)
    branches = run!(divide_alg, env, reform, divide_input)
    return new_children(space, branches, current)
end

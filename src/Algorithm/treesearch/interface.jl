# The definition of a tree search algorithm is based on three concepts.
"""
Contains the definition of the problem tackled by the tree search algorithm and how the
nodes and transitions of the tree search space will be explored.
"""
abstract type AbstractSearchSpace end

"Algorithm that chooses next node to evaluated in the tree search algorithm."
abstract type AbstractExploreStrategy end

"A subspace obtained by successive divisions of the search space."
abstract type AbstractNode end

"Returns the type of search space depending on the tree-search algorithm and its parameters."
@mustimplement "TreeSearch" search_space_type(::AbstractAlgorithm)

"Creates and returns the search space of a tree search algorithm, its model, and its input."
@mustimplement "TreeSearch"  new_space(::Type{<:AbstractSearchSpace}, alg, model, input)

"Creates and returns the root node of a search space."
@mustimplement "TreeSearch" new_root(::AbstractSearchSpace, input)

"Returns the root node of the tree to which the node belongs."
@mustimplement "Node" get_root(::AbstractNode)

"Returns the parent of a node; `nothing` if the node is the root."
@mustimplement "Node" get_parent(::AbstractNode)

"Returns the priority of the node depending on the explore strategy."
@mustimplement "Node" get_priority(::AbstractExploreStrategy, ::AbstractNode)

##### Addition methods for the node interface (needed by conquer)
"Returns an `OptimizationState` that contains best bounds and solutions at the node."
@mustimplement "Node" get_opt_state(::AbstractNode) # conquer, divide

@mustimplement "Node" set_records!(::AbstractNode, records)

"Returns a `Records` that allows to restore the state of the formulation at this node."
@mustimplement "Node" get_records(::AbstractNode) # conquer

"Returns a `String` to display the branching constraint."
@mustimplement "Node" get_branch_description(::AbstractNode) # printer

"Returns `true` is the node is root; `false` otherwise."
@mustimplement "Node" isroot(::AbstractNode) # BaB implementation

abstract type AbstractNodeUserInfo end

struct DummyUserInfo <: AbstractNodeUserInfo end

"Sets the user info stored at the node"
@mustimplement "Node" set_user_info!(::AbstractNode, ::AbstractNodeUserInfo)

"Gets the user info stored at the node"
@mustimplement "Node" get_user_info(::AbstractNode)

"Notifies the change in the current user info because a new node started to be treated"
@mustimplement "NodeUserInfo" notify_user_info_change(::AbstractNodeUserInfo)

"Records the updated user info value in the current node"
@mustimplement "NodeUserInfo" record_user_info(::AbstractNodeUserInfo)

# TODO: remove untreated nodes.
"Evaluate and generate children. This method has a specific implementation for Coluna."
@mustimplement "TreeSearch" children(sp, n, env, untreated_nodes)

"Returns true if stopping criteria are met; false otherwise."
@mustimplement "TreeSearch" stop(::AbstractSearchSpace, untreated_nodes)

# TODO: remove untreated nodes.
"Returns the output of the tree search algorithm."
@mustimplement "TreeSearch" tree_search_output(::AbstractSearchSpace, untreated_nodes)

############################################################################################
# Tree search interface for Coluna algorithms
############################################################################################
"Search space for tree search algorithms in Coluna."
abstract type AbstractColunaSearchSpace <: AbstractSearchSpace end

# Additional methods to implement to use the tree search algorithms together with Coluna's
# algorithms.
"Returns the previous node explored by the tree search algorithm."
@mustimplement "ColunaSearchSpace" get_previous(s::AbstractColunaSearchSpace)

"Sets the previous node explored by the tree search algorithm."
@mustimplement "ColunaSearchSpace" set_previous!(s::AbstractColunaSearchSpace, previous)

"Returns the conquer algorithm."
@mustimplement "ColunaSearchSpace" get_conquer(sp::AbstractColunaSearchSpace)

"Returns the divide algorithm."
@mustimplement "ColunaSearchSpace" get_divide(sp::AbstractColunaSearchSpace)

"Returns the reformulation that will be passed to an algorithm."
@mustimplement "ColunaSearchSpace" get_reformulation(s::AbstractColunaSearchSpace)

"""
Returns the input that will be passed to an algorithm.
The input can be built from information contained in a search space and a node.
"""
@mustimplement "ColunaSearchSpace" get_input(a::AbstractAlgorithm, s::AbstractColunaSearchSpace, n::AbstractNode)

"""
Methods to perform operations before the tree search algorithm evaluates a node (`current`).
This is useful to restore the state of the formulation for instance.
"""
@mustimplement "ColunaSearchSpace" node_change!(previous::AbstractNode, current::AbstractNode, space::AbstractColunaSearchSpace, untreated_nodes)

"""
Methods to perform operations after the conquer algorithms.
It receives the output of the conquer algorithm.
"""
@mustimplement "ColunaSearchSpace" after_conquer!(::AbstractColunaSearchSpace, current, output)

"Creates and returns the children of a node associated to a search space."
@mustimplement "ColunaSearchSpace" new_children(sp::AbstractColunaSearchSpace, candidates, n::AbstractNode)

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

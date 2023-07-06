
### WIP
### Node for the strong branching (Goal: decouple strong branching from tree search)
### TODO: transform into a very light node dedicated to the strong branching algorithm.
### This light node will contain information to generate the real node of the tree search.
mutable struct SbNode{Node<:TreeSearch.AbstractNode} <: TreeSearch.AbstractNode
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    var_name::String
    branchdescription::String
    records::Records
    conquerwasrun::Bool
    function SbNode(
        form::AbstractFormulation, parent::N, var_name::String, branch_description::String, records::Records
    ) where {N <: TreeSearch.AbstractNode}
        depth = getdepth(parent) + 1
        node_state = OptimizationState(form, TreeSearch.get_opt_state(parent), true, true)
        return new{N}(depth, parent, node_state, var_name, branch_description, records, false)
    end
end

# TODO remove
function to_be_pruned(node::SbNode)
    nodestate = TreeSearch.get_opt_state(node)
    getterminationstatus(nodestate) == INFEASIBLE && return true
    return ip_gap_closed(nodestate)
end

getdepth(n::SbNode) = n.depth

TreeSearch.get_opt_state(n::SbNode) = n.optstate
TreeSearch.set_records!(n::SbNode, records) = n.records = records
TreeSearch.get_parent(n::SbNode) = n.parent
TreeSearch.get_branch_description(n::SbNode) = n.branchdescription
get_var_name(n::SbNode) = n.var_name
TreeSearch.isroot(n::SbNode) = false
Branching.isroot(n::SbNode) = TreeSearch.isroot(n)

### WIP
### Node for the strong branching (Goal: decouple strong branching from tree search)
### TODO: transform into a very light node dedicated to the strong branching algorithm.
### This light node will contain information to generate the real node of the tree search.
mutable struct SbNode{Node<:AbstractNode} <: AbstractNode
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    branchdescription::String
    records::Records
    conquerwasrun::Bool
    function SbNode(
        form::AbstractFormulation, parent::N, branch_description::String, records::Records
    ) where {N <: AbstractNode}
        depth = getdepth(parent) + 1
        node_state = OptimizationState(form, get_opt_state(parent), false, false)
        return new{N}(depth, parent, node_state, branch_description, records, false)
    end
end

# TODO remove
function to_be_pruned(node::SbNode)
    nodestate = get_opt_state(node)
    getterminationstatus(nodestate) == INFEASIBLE && return true
    return ip_gap_closed(nodestate)
end

getdepth(n::SbNode) = n.depth

get_opt_state(n::SbNode) = n.optstate
get_records(n::SbNode) = n.records
set_records!(n::SbNode, records) = n.records = records
get_parent(n::SbNode) = n.parent
get_branch_description(n::SbNode) = n.branchdescription
isroot(n::SbNode) = false
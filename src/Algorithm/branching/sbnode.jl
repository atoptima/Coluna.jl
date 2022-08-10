
### WIP
### Node for the strong branching (Goal: decouple strong branching from tree search)
### TODO: transform into a very light node dedicated to the strong branching algorithm.
### This light node will contain information to generate the real node of the tree search.
mutable struct SbNode 
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    branchdescription::String
    recordids::RecordsVector
    conquerwasrun::Bool
end

# this function creates a child node by copying info from another child
# used in strong branching
function SbNode(parent::Node, child::SbNode)
    depth = getdepth(parent) + 1
    return SbNode(
        depth, parent, getoptstate(child),
        child.branchdescription, child.recordids, false
    )
end

function SbNode(
    form::AbstractFormulation, parent::Node, branchdescription::String, recordrecordids::RecordsVector
)
    depth = getdepth(parent) + 1
    nodestate = OptimizationState(form, getoptstate(parent), false, false)
    
    return SbNode(
        depth, parent, nodestate, branchdescription, recordrecordids, false
    )
end

function Node(node::SbNode, tree_order)
    return Node(tree_order, node.depth, node.parent, node.optstate, node.branchdescription, node.recordids, node.conquerwasrun)
end

# TODO remove
function to_be_pruned(node::SbNode)
    nodestate = getoptstate(node)
    getterminationstatus(nodestate) == INFEASIBLE && return true
    return ip_gap_closed(nodestate)
end

getdepth(n::SbNode) = n.depth
getparent(n::SbNode) = n.parent
getchildren(n::SbNode) = n.children
getoptstate(n::SbNode) = n.optstate
addchild!(n::SbNode, child::SbNode) = push!(n.children, child)

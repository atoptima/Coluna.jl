####################################################################
#                      Node
####################################################################

mutable struct Node <: AbstractNode
    tree_order::Int
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    #branch::Union{Nothing, Branch} # branch::ConstrId
    branchdescription::String
    recordids::RecordsVector
    conquerwasrun::Bool
end

function RootNode(
    form::AbstractFormulation, optstate::OptimizationState, recordrecordids::RecordsVector, skipconquer::Bool
)
    nodestate = OptimizationState(form, optstate, false, skipconquer)
    tree_order = skipconquer ? 0 : -1
    return Node(
        tree_order, 0, nothing, nodestate, "", recordrecordids, skipconquer
    )
end

function Node(
    form::AbstractFormulation, parent::Node, branchdescription::String, recordrecordids::RecordsVector
)
    depth = getdepth(parent) + 1
    nodestate = OptimizationState(form, getoptstate(parent), false, false)
    
    return Node(
        -1, depth, parent, nodestate, branchdescription, recordrecordids, false
    )
end


get_tree_order(n::Node) = n.tree_order
set_tree_order!(n::Node, tree_order::Int) = n.tree_order = tree_order
getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getoptstate(n::Node) = n.optstate
addchild!(n::Node, child::Node) = push!(n.children, child)
isrootnode(n::Node) = n.tree_order == 1

# TODO remove
function to_be_pruned(node::Node)
    nodestate = getoptstate(node)
    getterminationstatus(nodestate) == INFEASIBLE && return true
    return ip_gap_closed(nodestate)
end

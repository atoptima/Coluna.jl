####################################################################
#                      Node
####################################################################

mutable struct Node 
    tree_order::Int
    istreated::Bool
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    #branch::Union{Nothing, Branch} # branch::Id{Constraint}
    branchdescription::String
    stateids::StorageStatesVector
    conquerwasrun::Bool
end

function RootNode(
    form::AbstractFormulation, optstate::OptimizationState, storagestateids::StorageStatesVector, skipconquer::Bool
)
    nodestate = CopyBoundsAndStatusesFromOptState(form, optstate, false, skipconquer)
    tree_order = skipconquer ? 1 : -1
    return Node(
        tree_order, false, 0, nothing, nodestate, "", storagestateids, skipconquer
    )
end

function Node(
    form::AbstractFormulation, parent::Node, branchdescription::String, storagestateids::StorageStatesVector
)
    depth = getdepth(parent) + 1
    nodestate = CopyBoundsAndStatusesFromOptState(form, getoptstate(parent), false, false)
    
    return Node(
        -1, false, depth, parent, nodestate, branchdescription, storagestateids, false
    )
end

# this function creates a child node by copying info from another child
# used in strong branching
function Node(parent::Node, child::Node)
    depth = getdepth(parent) + 1
    return Node(
        -1, false, depth, parent, getoptstate(child),
        child.branchdescription, child.stateids, false
    )
end

get_tree_order(n::Node) = n.tree_order
set_tree_order!(n::Node, tree_order::Int) = n.tree_order = tree_order
getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getoptstate(n::Node) = n.optstate
addchild!(n::Node, child::Node) = push!(n.children, child)
settreated!(n::Node) = n.istreated = true
istreated(n::Node) = n.istreated
isrootnode(n::Node) = n.tree_order == 1
getinfeasible(n::Node) = n.infesible
setinfeasible(n::Node, status::Bool) = n.infeasible = status

function to_be_pruned(node::Node)
    nodestate = getoptstate(node)
    getterminationstatus(nodestate) == INFEASIBLE && return true
    bounds_ratio = get_ip_primal_bound(nodestate) / get_ip_dual_bound(nodestate)
    return isapprox(bounds_ratio, 1) || ip_gap(nodestate) < 0
end

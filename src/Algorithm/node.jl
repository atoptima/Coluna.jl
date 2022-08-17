####################################################################
#                      Node
####################################################################

mutable struct Node <: AbstractNode
    depth::Int
    parent::Union{Nothing, Node}
    optstate::OptimizationState
    branchdescription::String
    records::Records
    conquerwasrun::Bool
end

getdepth(n::Node) = n.depth
getparent(n::Node) = n.parent
getchildren(n::Node) = n.children
getoptstate(n::Node) = n.optstate
addchild!(n::Node, child::Node) = push!(n.children, child)
isrootnode(n::Node) = n.depth == 0
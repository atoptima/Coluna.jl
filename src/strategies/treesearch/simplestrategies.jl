# Depth-first strategy
struct DepthFirst <: AbstractTreeSearchStrategy end
apply!(::Type{DepthFirst}, n::AbstractNode) = (-n.depth)

# Best dual bound strategy
struct BestDualBound <: AbstractTreeSearchStrategy end
apply!(::Type{BestDualBound}, n::AbstractNode) = get_ip_dual_bound(getincumbents(n))
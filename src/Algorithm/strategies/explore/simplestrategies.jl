# Depth-first strategy
struct DepthFirst <: AbstractExploreStrategy end
apply!(algo::DepthFirst, n::AbstractNode) = (-n.depth)

# Best dual bound strategy
struct BestDualBound <: AbstractExploreStrategy end
apply!(algo::BestDualBound, n::AbstractNode) = get_ip_dual_bound(getincumbents(n))
"""
    AbstractTreeSearchStrategy

A TreeSearchStrategy is defines how the branch-and-bound tree shall be
searhed. To define a concrete `AbstractTreeSearchStrategy` one must define the function
`apply!(strategy::Type{<:AbstractTreeSearchStrategy}, n::Node)`.
"""
abstract type AbstractTreeSearchStrategy <: AbstractStrategy end

"""
    apply!(S::Type{<:AbstractTreeSearchStrategy}, n::Node)::Real

computes the `Node` `n` preference to be treated according to 
the strategy type `S` and returns the corresponding Real number.
"""

# Fallback
function apply!(S::Type{<:AbstractTreeSearchStrategy}, args...)
    error("Method apply! not implemented for conquer strategy $S.")
end

# Depth-first strategy
struct DepthFirst <: AbstractTreeSearchStrategy end
apply!(::Type{DepthFirst}, n::AbstractNode) = (-n.depth)

# Best dual bound strategy
struct BestDualBound <: AbstractTreeSearchStrategy end
apply!(::Type{BestDualBound}, n::AbstractNode) = get_ip_dual_bound(getincumbents(n))
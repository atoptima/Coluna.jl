"""
    AbstractConquerStrategy

Conquer strategy is a combination of `Algorithms` to treat a node of the
branch-and-bound tree.
"""
abstract type AbstractConquerStrategy <: AbstractStrategy end

"""
    AbstractDivideStrategy

Divide strategy is a combination of `Algorithms`that generates one or more children
branch-and-bound node.
"""
abstract type AbstractDivideStrategy <: AbstractStrategy end

"""
    AbstractTreeSearchStrategy

A TreeSearchStrategy defines how the branch-and-bound tree shall be
searhed. To define a concrete `AbstractTreeSearchStrategy` one must define the function
`apply!(strategy::Type{<:AbstractTreeSearchStrategy}, n::Node)`.
"""
abstract type AbstractTreeSearchStrategy <: AbstractStrategy end

"""
    apply!(strategy::AbstractStrategy, args...)

Apply `strategy` to whatever context such strategy is defined for.

    apply!(strategy::AbstractDivideStrategy, reformulation, node)

Apply the divide strategy on a `reformulation` in the `node`.

    apply!(strategy::AbstractDivideStrategy, reformulation, node)

Apply the conquer strategy on a `reformulation` in the `node`.

    apply!(strategy::AbstractDivideStrategy, n::Node)::Real

computes the `Node` `n` preference to be treated according to 
the strategy type `S` and returns the corresponding Real number.
"""
function apply! end

# Fallback
function apply!(strategy::AbstractStrategy, args...)
    strategy_type = typeof(strategy)
    error("Method apply! not implemented for strategy $(strategy_type).")
end

"""
    GlobalStrategy

A GlobalStrategy encapsulates all three strategies necessary to define Coluna's behavious 
in solving a `Reformulation`. Each `Reformulation` keeps an objecto of type GlobalStrategy.
"""
struct GlobalStrategy <: AbstractStrategy
    conquer::AbstractConquerStrategy
    divide::AbstractDivideStrategy
    tree_search::AbstractTreeSearchStrategy
end

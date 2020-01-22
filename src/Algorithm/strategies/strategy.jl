"""
    AbstractConquerStrategy

Conquer strategy is a combination of `Algorithms` to treat a node of the
branch-and-bound tree.
"""
abstract type AbstractConquerStrategy <: AbstractStrategy end

# should return true if the strategy outputs more than one line 
# it is used by strong branching
isverbose(strategy::AbstractConquerStrategy) = false

"""
    AbstractDivideStrategy

Divide strategy is a combination of `Algorithms`that generates one or more children
branch-and-bound node.
"""
abstract type AbstractDivideStrategy <: AbstractStrategy end

"""
    AbstractExploreStrategy

An ExploreStrategy defines how the branch-and-bound tree shall be
searched. To define a concrete `AbstractExploreStrategy`, one must define 
the function
`apply!(strategy::Type{<:AbstractExploreStrategy}, n::Node)`.
"""
abstract type AbstractExploreStrategy <: AbstractStrategy end

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

# definition of the preparation function is optional
prepare!(strategy::AbstractStrategy, reform::AbstractFormulation) = nothing

"""
    GlobalStrategy

A GlobalStrategy encapsulates all three strategies necessary to define Coluna's behavious 
in solving a `Reformulation`. Each `Reformulation` keeps an objecto of type GlobalStrategy.
"""
struct GlobalStrategy <: AbstractGlobalStrategy
    conquer::AbstractConquerStrategy
    divide::AbstractDivideStrategy
    explore::AbstractExploreStrategy
end

function prepare!(strategy::GlobalStrategy, reform::AbstractFormulation)
    prepare!(strategy.conquer, reform)
    prepare!(strategy.divide, reform)
    prepare!(strategy.explore, reform)
end

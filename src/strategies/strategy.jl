mutable struct StrategyRecord
    cur_solver::Type{<:AbstractSolver}
    ext::Dict{Symbol, Any}
end

StrategyRecord() = StrategyRecord(StartNode, Dict{Symbol, Any}())

setsolver!(r::StrategyRecord, s::Type{<:AbstractSolver}) = r.cur_solver = s
getsolver(r::StrategyRecord) = r.cur_solver

"""
    AbstractConquerStrategy

Conquer strategy is a combination of `Solvers` to treat a node of the
branch-and-bound tree.
"""
abstract type AbstractConquerStrategy <: AbstractStrategy end

"""
    AbstractDivideStrategy

Divide strategy is a combination of `Solvers`that generates one or more children
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
    apply!(S::Type{<:AbstractStrategy}, args...)

Applies the strategy `S` to whatever context such strategy is defined for.

    apply!(::Type{<:AbstractDivideStrategy}, reformulation, node, strategy_record, params)

Applies the divide strategy on a `reformulation` in the `node` with `parameters`.

    apply!(::Type{<:AbstractConquerStrategy}, reformulation, node, strategy_record, params)

Applies the conquer strategy on a `reformulation` in the `node` with `parameters`.

    apply!(S::Type{<:AbstractTreeSearchStrategy}, n::Node)::Real

computes the `Node` `n` preference to be treated according to 
the strategy type `S` and returns the corresponding Real number.
"""
function apply! end

# Fallback
function apply!(S::Type{<:AbstractStrategy}, args...)
    error("Method apply! not implemented for conquer strategy $S.")
end

"""
    GlobalStrategy

A GlobalStrategy encapsulates all three strategies necessary to define Coluna's behavious 
in solving a `Reformulation`. Each `Reformulation` keeps an objecto of type GlobalStrategy.
"""
struct GlobalStrategy <: AbstractStrategy
    conquer::Type{<:AbstractConquerStrategy}
    divide::Type{<:AbstractDivideStrategy}
    tree_search::Type{<:AbstractTreeSearchStrategy}
end

"""
    GlobalStrategy()

Constructs a default GlobalStrategy using the strategies 
`SimpleBnP` as Conquer Strategy, `SimpleBranching` as DivideStrategy 
and `DepthFirst` as TreeSearchStrategy.
"""
GlobalStrategy() = GlobalStrategy(SimpleBnP, SimpleBranching, DepthFirst)

function apply!(S::Type{<:GlobalStrategy}, args...)
    error("Method apply! is not supposed to be implemented for the Global Strategies.")
end
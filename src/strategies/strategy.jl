mutable struct StrategyRecord
    cur_solver::Type{<:AbstractSolver}
    ext::Dict{Symbol, Any}
end

StrategyRecord() = StrategyRecord(StartNode, Dict{Symbol, Any}())

setsolver!(r::StrategyRecord, s::Type{<:AbstractSolver}) = r.cur_solver = s
getsolver(r::StrategyRecord) = r.cur_solver

abstract type AbstractConquerStrategy <: AbstractStrategy end
abstract type AbstractDivideStrategy <: AbstractStrategy end
abstract type AbstractTreeSearchStrategy <: AbstractStrategy end

"""
    apply!(S::Type{<:AbstractStrategy}, args...)

Applies the strategy `S` to whatever such strategy is defined for.
"""
function apply! end

struct GlobalStrategy <: AbstractStrategy
    conquer::Type{<:AbstractConquerStrategy}
    divide::Type{<:AbstractDivideStrategy}
    tree_search::Type{<:AbstractTreeSearchStrategy}
end

GlobalStrategy() = GlobalStrategy(SimpleBnP, SimpleBranching, DepthFirst)
abstract type AbstractStrategy end

mutable struct StrategyRecord
    cur_solver::Type{<:AbstractSolver}
    ext::Dict{Symbol, Any}
end

StrategyRecord() = StrategyRecord(StartNode, Dict{Symbol, Any}())

setsolver!(r::StrategyRecord, s::Type{<:AbstractSolver}) = r.cur_solver = s
getsolver(r::StrategyRecord) = r.cur_solver

abstract type AbstractStrategy end

mutable struct StrategyRecord
    cur_solver::Type{<:AbstractSolver}
    do_branching::Bool
end
StrategyRecord() = StrategyRecord(StartNode, true)
setsolver!(r::StrategyRecord, s::Type{<:AbstractSolver}) = r.cur_solver = s
getsolver(r::StrategyRecord) = r.cur_solver

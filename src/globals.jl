@with_kw mutable struct GlobalValues
    initial_solve_time::Float64 = 0.0
end

global const _to = TO.TimerOutput()

_elapsed_solve_time() = (time() - _globals_.initial_solve_time)

Base.isinteger(x::Float64, tol::Float64) = abs(round(x) - x) < tol
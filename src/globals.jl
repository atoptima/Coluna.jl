Base.@kwdef mutable struct GlobalValues
    initial_solve_time::Float64 = 0.0
    MAX_PROCESSES::Int = 100
    MAX_FORMULATIOS::Int = 100
end

global const _to = TO.TimerOutput()

_elapsed_solve_time() = (time() - _globals_.initial_solve_time)

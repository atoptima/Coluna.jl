Base.@kwdef mutable struct GlobalValues
    initial_solve_time::Float64 = 0.0
    MAX_SV_ENTRIES::Int = 10_000_000
    MAX_PROCESSES::Int = 100
    MAX_FORMULATIOS::Int = 100
end

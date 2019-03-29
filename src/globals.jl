Base.@kwdef mutable struct GlobalValues
    initial_solve_time::Float64 = 0.0
    MAX_SV_ENTRIES::Int = 10_000_000
end

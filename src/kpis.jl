mutable struct Kpis
    node_count::Union{Missing, Int} # missing by default ?
    elapsed_optimization_time::Union{Missing, Float64}
end
Base.@kwdef mutable struct Params
    max_num_nodes::Int = 10000
    open_nodes_limit::Int = 100000
    #integrality_tolerance::Float64 = 1e-5
    #absolute_optimality_tolerance::Float64 = 1e-5
    #relative_optimality_tolerance::Float64 = 1e-5
    tol::Float64 = 1e-8 # if - ϵ_tol < val < ϵ_tol, we consider val = 0
    tol_digits::Int = 8 # because round(val, digits = n) where n is from 1e-n
    cut_up::Float64 = Inf
    cut_lo::Float64 = -Inf
    force_copy_names::Bool = false
    solver::AbstractOptimizationAlgorithm = TreeSearchAlgorithm() 
end

update_field!(f_v::Tuple{Symbol,Any}) = setfield!(_params_, f_v[1], f_v[2])
_set_global_params(p::Params) = map(update_field!, [(f, getfield(p, f)) for f in fieldnames(Params)])

"""
    Coluna.Params(
        solver = Coluna.Algorithm.TreeSearchAlgorithm(),
        global_art_var_cost = 10e6,
        local_art_var_cost = 10e4
    )

Parameters of Coluna :
- `solver` is the algorithm used to optimize the reformulation.
- `global_art_var_cost` is the cost of the global artificial variables in the master
- `local_art_var_cost` is the cost of the local artificial variables in the master
"""
@with_kw mutable struct Params
    tol::Float64 = 1e-8 # if - ϵ_tol < val < ϵ_tol, we consider val = 0
    tol_digits::Int = 8 # because round(val, digits = n) where n is from 1e-n
    global_art_var_cost::Union{Float64, Nothing} = nothing
    local_art_var_cost::Union{Float64, Nothing} = nothing
    solver = nothing
    max_nb_processes::Int = 100
    max_nb_formulations::Int = 200
end

update_field!(f_v::Tuple{Symbol,Any}) = setfield!(_params_, f_v[1], f_v[2])
_set_global_params(p::Params) = map(update_field!, [(f, getfield(p, f)) for f in fieldnames(Params)])

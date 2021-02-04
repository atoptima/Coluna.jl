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
    global_art_var_cost::Union{Float64, Nothing} = nothing
    local_art_var_cost::Union{Float64, Nothing} = nothing
    solver = nothing
end

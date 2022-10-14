mutable struct Env{Id}
    env_starting_time::DateTime
    optim_starting_time::Union{Nothing, DateTime}
    global_time_limit::Int64 # -1 means no time limit
    params::Params
    kpis::Kpis
    form_counter::Int # 0 is for original form
    var_counter::Int
    constr_counter::Int
    varids::MOI.Utilities.CleverDicts.CleverDict{MOI.VariableIndex, Id}
    custom_families_id::Dict{DataType, Int}
end

Env{Id}(params::Params) where {Id} = Env{Id}(
    now(), nothing, -1, params, Kpis(nothing, nothing), 0, 0, 0,
    MOI.Utilities.CleverDicts.CleverDict{MOI.VariableIndex, Id}(),
    Dict{DataType, Int}()
)
set_optim_start_time!(env::Env) = env.optim_starting_time = now()
elapsed_optim_time(env::Env) = Dates.toms(now() - env.optim_starting_time) / Dates.toms(Second(1))
time_limit_reached(env::Env) = env.global_time_limit > 0 && elapsed_optim_time(env) > env.global_time_limit
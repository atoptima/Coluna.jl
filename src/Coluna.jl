module Coluna

# Base functions for which we define more methods in Coluna
import Base: isempty, hash, isequal, length, iterate, getindex, lastindex,
    getkey, delete!, setindex!, haskey, copy, promote_rule, convert, isinteger,
    push!, filter, diff, hcat

import BlockDecomposition, MathOptInterface, TimerOutputs

using Base.Threads, Dates, Distributed, DynamicSparseArrays, Logging, Parameters, Printf

const BD = BlockDecomposition
const MOI = MathOptInterface
const TO = TimerOutputs

### Default parameters values
const DEF_OPTIMALITY_ATOL = 1e-5
const DEF_OPTIMALITY_RTOL = 1e-9

const TOL = 1e-8 # if - ϵ_tol < val < ϵ_tol, we consider val = 0
const TOL_DIGITS = 8 # because round(val, digits = n) where n is from 1e-n
###

# submodules
export ColunaBase, MathProg, Algorithm

const _to = TO.TimerOutput()

export Algorithm, ColunaBase, MathProg, Env, DefaultOptimizer, Parameters,
    elapsed_optim_time

include("kpis.jl")

include("parameters.jl")

include("ColunaBase/ColunaBase.jl")
using .ColunaBase

mutable struct Env
    env_starting_time::DateTime
    optim_starting_time::Union{Nothing, DateTime}
    params::Params
    kpis::Kpis
    form_counter::Int # 0 is for original form
end
Env(params::Params) = Env(now(), nothing, params, Kpis(nothing, nothing), 0)
set_optim_start_time!(env::Env) = env.optim_starting_time = now()
elapsed_optim_time(env::Env) = Dates.toms(now() - env.optim_starting_time) / Dates.toms(Second(1))
Base.isinteger(x::Float64, tol::Float64) = abs(round(x) - x) < tol

include("MathProg/MathProg.jl")
using .MathProg

include("Algorithm/Algorithm.jl")
using .Algorithm

include("annotations.jl")
include("optimize.jl")

# Wrapper functions
include("MOIwrapper.jl")
include("MOIcallbacks.jl")
include("decomposition.jl")

end # module

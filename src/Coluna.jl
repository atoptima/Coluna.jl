module Coluna

# Base functions for which we define more methods in Coluna
import Base: isempty, hash, isequal, length, iterate, getindex, lastindex,
    getkey, delete!, setindex!, haskey, copy, promote_rule, convert, isinteger,
    push!, filter, diff, hcat, in

import BlockDecomposition, MathOptInterface, TimerOutputs

using Base.Threads, Dates, DynamicSparseArrays, Logging, Parameters, Printf, TOML

const BD = BlockDecomposition
const MOI = MathOptInterface
const TO = TimerOutputs

### Default parameters values
const DEF_OPTIMALITY_ATOL = 1e-5
const DEF_OPTIMALITY_RTOL = 1e-9

const TOL = 1e-8 # if - ϵ_tol < val < ϵ_tol, we consider val = 0
const TOL_DIGITS = 8 # because round(val, digits = n) where n is from 1e-n

const MAX_NB_ELEMS = typemax(Int32) # max number of variables or constraints.
###

# submodules
export Algorithm, ColunaBase, MathProg, Env, DefaultOptimizer, Parameters,
    elapsed_optim_time

const _to = TO.TimerOutput()

version() = v"0.6.6"

include("kpis.jl")
include("parameters.jl")
include("env.jl")
export Env

include("MustImplement/MustImplement.jl")
using .MustImplement

include("ColunaBase/ColunaBase.jl")
using .ColunaBase

include("MathProg/MathProg.jl")
using .MathProg

include("interface.jl")
using .AlgoAPI

include("TreeSearch/TreeSearch.jl")
using .TreeSearch

include("Branching/Branching.jl")
using .Branching

include("ColGen/ColGen.jl")
using .ColGen

include("Benders/Benders.jl")
using .Benders

include("Heuristic/Heuristic.jl")
using .Heuristic

include("Algorithm/Algorithm.jl")
using .Algorithm

include("annotations.jl")
include("optimize.jl")

# Wrapper functions
include("MOIwrapper.jl")
include("MOIcallbacks.jl")
include("decomposition.jl")

end # module

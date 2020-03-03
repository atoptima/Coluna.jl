module Coluna

import BlockDecomposition
import MathOptInterface
import MathOptInterface.Utilities
import Distributed
import TimerOutputs
import Base.Threads

using Logging
using Printf

global const BD = BlockDecomposition
global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const TO = TimerOutputs

# submodules
export Containers, MathProg, Algorithm

# parameters
export Parameters, DefaultOptimizer

# Base functions for which we define more methods in Coluna
import Base: isempty, hash, isequal, length, iterate, getindex, lastindex,
    getkey, delete!, setindex!, haskey, copy, promote_rule, convert, isinteger,
    push!, filter, diff

include("interface.jl")
include("parameters.jl")
global const _params_ = Params()

include("Containers/Containers.jl")
using .Containers

include("MathProg/MathProg.jl")
using .MathProg
const MP = MathProg

include("Algorithm/Algorithm.jl")
using .Algorithm
const AL = Algorithm

include("optimize.jl")

# Wrapper functions
include("MOIwrapper.jl")

# TODO : put global values here
include("globals.jl") # Structure that holds values useful in all the procedure

global const _globals_ = GlobalValues()
#export _params_, _globals_, _to # to be deleted

end # module

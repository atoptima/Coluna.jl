module Coluna

import BlockDecomposition
import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
import Distributed
import TimerOutputs

using Logging
using Printf

global const BD = BlockDecomposition
global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const DS = DataStructures
global const TO = TimerOutputs

# submodules
export Containers, MathProg

# Base functions for which we define more methods in Coluna
import Base: isempty, hash, isequal, length, iterate, getindex, lastindex,
    getkey, delete!, setindex!, haskey, copy, promote_rule, convert, isinteger,
    push!, filter, diff


include("containers/containers.jl")
using .Containers

include("types.jl")
include("parameters.jl")

include("MathProg/MathProg.jl")
using .MathProg

# To be deleted :
import .MathProg: getrhs, getsense, optimize!

include("algorithms/algorithm.jl")
include("strategies/strategy.jl")

include("node.jl")


# Concrete algorithms & Strategies :

# Here include algorithms
include("algorithms/colgen.jl")
include("algorithms/benders.jl")
include("algorithms/masteripheur.jl")
include("algorithms/masterlp.jl")
include("algorithms/reformulationsolver.jl")
include("algorithms/preprocessing.jl")

# Here include conquer strategies
include("strategies/conquer/simplebnp.jl")
include("strategies/conquer/simplebenders.jl")

# Here include branching algorithms
include("branching/abstractbranching.jl")
include("branching/varbranching.jl")
include("branching/branchinggroup.jl")
include("branching/branchingstrategy.jl")

# Here include divide strategies
include("strategies/divide/simplebranching.jl") # to remove

# Here include explore strategies
include("strategies/explore/simplestrategies.jl")

# Wrapper functions
include("MOIwrapper.jl")

# TODO : put global values here
include("globals.jl") # Structure that holds values useful in all the procedure

global const _params_ = Params()
global const _globals_ = GlobalValues()
#export _params_, _globals_, _to # to be deleted

end # module

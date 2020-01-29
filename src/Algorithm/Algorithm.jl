module Algorithm

import DataStructures
import MathOptInterface
import TimerOutputs

import ..Coluna
using ..Containers
using ..MathProg

# To be deleted :
import .MathProg: getrhs, getsense, optimize! # because of branch

using Logging
using Printf

const TO = TimerOutputs
const DS = DataStructures
const MOI = MathOptInterface

import Base: push!

# TODO clean up :
#export AbstractGlobalStrategy, EmptyGlobalStrategy

const MAX_NUM_NODES = 100 # TODO : rm & should be a parameter of the B&B Algorithm
const OPEN_NODES_LIMIT = 100 # TODO : rm & should be param of B&B algo

# Abstract algorithm
include("interface.jl")

# Abstract record
include("record.jl")

# Here include conquer algorithms
include("conquer.jl")
include("colgen.jl")
include("benders.jl")
include("masteripheur.jl")
include("masterlp.jl")
include("reformulationsolver.jl")
include("preprocessing.jl")

# Here include conquer strategies
include("strategies/conquer/simplebnp.jl")
include("strategies/conquer/simplebenders.jl")

include("node.jl") # TODO : break interdependance between node & Algorithm #224 & rm file

# Here include divide algorithms
include("branching/abstractbranching.jl")
include("branching/varbranching.jl")
include("branching/branchinggroup.jl")
include("branching/branchingstrategy.jl")

include("treesearch.jl")

# # Concrete algorithms & Strategies :
# include("strategies/strategy.jl")


# # Here include divide strategies
# include("strategies/divide/simplebranching.jl") # to remove

# Here include explore strategies
# include("strategies/explore/simplestrategies.jl")

end
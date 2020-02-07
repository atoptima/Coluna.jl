module Algorithm

import DataStructures
import MathOptInterface
import TimerOutputs

import ..Coluna
using ..Containers
using ..MathProg

# To be deleted :
import .MathProg: getrhs, getsense, optimize! # because of branch

# TO be deleted ???
import .MathProg: FeasibilityStatus, TerminationStatus, AbstractStorage, EmptyStorage, getstorage, setprimalbound!, setdualbound!
import .MathProg: OPTIMAL, TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, EMPTY_RESULT, NOT_YET_DETERMINED
import ..Coluna: AbstractSense

using Logging
using Printf

const TO = TimerOutputs
const DS = DataStructures
const MOI = MathOptInterface

import Base: push!

# TODO clean up :
#export AbstractGlobalStrategy, EmptyGlobalStrategy

# const MAX_NUM_NODES = 100 # TODO : rm & should be a parameter of the B&B Algorithm
# const OPEN_NODES_LIMIT = 100 # TODO : rm & should be param of B&B algo

# Abstract algorithm
include("interface.jl")

# Abstract record
include("record.jl")

# Here include slave algorithms used by conquer algorithms
include("colgen.jl")
include("benders.jl")
include("masteripheur.jl")
include("masterlp.jl")
include("preprocessing.jl")

# Here include conquer algorithms
include("conquer.jl")

include("node.jl") # TODO : break interdependance between node & Algorithm #224 & rm file

include("divide.jl")

# Here include divide algorithms
include("branching/branchinggroup.jl")
include("branching/branchingrule.jl")
include("branching/varbranching.jl")
include("branching/branchingalgo.jl")

include("treesearch.jl")

# Types
export AbstractOptimizationAlgorithm, TreeSearchAlgorithm, ColGenConquer, ColumnGeneration, 
       BendersConquer, BendersCutGeneration, MasterIpHeuristic, ExactBranchingPhase, 
       OnlyRestrictedMasterBranchingPhase



# Here include conquer strategies
# include("strategies/conquer/simplebnp.jl")
# include("strategies/conquer/simplebenders.jl")

# # Concrete algorithms & Strategies :
# include("strategies/strategy.jl")

# include("reformulationsolver.jl")

# # Here include divide strategies
# include("strategies/divide/simplebranching.jl") # to remove

# Here include explore strategies
# include("strategies/explore/simplestrategies.jl")

end
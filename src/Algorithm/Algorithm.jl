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

import .MathProg: get_lp_primal_sol, get_lp_dual_bound, setfeasibilitystatus!, setterminationstatus!, getvalue

using Logging
using Printf

const TO = TimerOutputs
const DS = DataStructures
const MOI = MathOptInterface

import Base: push!

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

end
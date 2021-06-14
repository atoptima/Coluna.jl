module Algorithm

import DataStructures
import MathOptInterface
import TimerOutputs

using ..Coluna, ..ColunaBase, ..MathProg

using DynamicSparseArrays, Logging, Parameters, Printf, Statistics

const TO = TimerOutputs
const DS = DataStructures
const MOI = MathOptInterface

import Base: push!

# Utilities to build algorithms
include("utilities/optimizationstate.jl")

include("data.jl")
include("formstorages.jl")

# Abstract algorithm
include("interface.jl")

# Basic algorithms
include("basic/solvelpform.jl")
include("basic/solveipform.jl")
include("basic/cutcallback.jl")

# Child algorithms used by conquer algorithms
include("colgenstabilization.jl")
include("colgen.jl")
include("benders.jl")
include("preprocessing.jl")

# Algorithms and structures used by the tree search algorithm
include("node.jl")
include("conquer.jl")
include("divide.jl")

# Here include divide algorithms
include("branching/branchinggroup.jl")
include("branching/branchingrule.jl")
include("branching/varbranching.jl")
include("branching/branchingalgo.jl")

include("treesearch.jl")

# Algorithm should export only methods usefull to define & parametrize algorithms, and
# data structures from utilities.
# Other Coluna's submodules should be independent to Algorithm

# Utilities
export getterminationstatus, setterminationstatus!,
    get_ip_primal_sols, get_lp_primal_sols, get_lp_dual_sols, get_best_ip_primal_sol,
    get_best_lp_primal_sol, get_best_lp_dual_sol, update_ip_primal_sol!,
    update_lp_primal_sol!, update_lp_dual_sol!, add_ip_primal_sol!, add_ip_primal_sols!,
    add_lp_primal_sol!, add_lp_dual_sol!, set_ip_primal_sol!, set_lp_primal_sol!, set_lp_dual_sol!,
    empty_ip_primal_sols!, empty_lp_primal_sols!, empty_lp_dual_sols!,
    get_ip_primal_bound, get_lp_primal_bound, get_lp_dual_bound, get_ip_dual_bound, 
    set_ip_primal_bound!, set_lp_primal_bound!, set_lp_dual_bound!, set_ip_dual_bound!,
    update_ip_primal_bound!, update_lp_primal_bound!, update_lp_dual_bound!, update_ip_dual_bound!,
    getoptstate, run!, isinfeasible
    
# Algorithm's types
export AbstractOptimizationAlgorithm, TreeSearchAlgorithm, ColCutGenConquer, ColumnGeneration,
       BendersConquer, BendersCutGeneration, SolveIpForm, RestrictedMasterIPHeuristic,
       SolveLpForm, ExactBranchingPhase, OnlyRestrictedMasterBranchingPhase, PreprocessAlgorithm, 
       OptimizationInput, OptimizationOutput, OptimizationState, EmptyInput

# Types of optimizers
export MoiOptimize, UserOptimizer

# Units 
export PartialSolutionUnit, PreprocessingUnit

# Unit functions 
export add_to_solution!, add_to_localpartialsol!

end

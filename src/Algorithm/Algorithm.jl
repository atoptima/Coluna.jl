module Algorithm

import DataStructures
import MathOptInterface
import TimerOutputs

using ..Coluna
using ..Containers
using ..MathProg

# TO be deleted ???
import .MathProg: FeasibilityStatus, TerminationStatus, AbstractStorage, EmptyStorage, getstorage, setprimalbound!, setdualbound!
import .MathProg: OPTIMAL, TIME_LIMIT, NODE_LIMIT, OTHER_LIMIT, EMPTY_RESULT, NOT_YET_DETERMINED
import ..Coluna: AbstractSense

import .MathProg: getvalue

using Logging
using Printf

const TO = TimerOutputs
const DS = DataStructures
const MOI = MathOptInterface

import Base: push!

# Import to extend methods to OptimizationState
import .MathProg: getfeasibilitystatus, getterminationstatus, setfeasibilitystatus!,
    setterminationstatus!, isfeasible, get_ip_primal_bound, get_ip_dual_bound, 
    get_lp_primal_bound, get_lp_dual_bound, update_ip_primal_bound!, update_ip_dual_bound!, 
    update_lp_primal_bound!, update_lp_dual_bound!, set_ip_primal_bound!, 
    set_ip_dual_bound!, set_lp_primal_bound!, set_lp_dual_bound!, ip_gap

# Utilities to build algorithms
include("utilities/optimizationstate.jl")
include("utilities/record.jl")

# Abstract algorithm (interface should be moved in Containers)
include("interface.jl")

# Here include slave algorithms used by conquer algorithms
include("solveipform.jl")
include("solvelpform.jl")
include("colgen.jl")
include("benders.jl")
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

# Algorithm should export only methods usefull to define & parametrize algorithms, and 
# data structures from utilities.
# Other Coluna's submodules should be independent to Algorithm

# Utilities
export OptimizationState, getterminationstatus, getfeasibilitystatus, setterminationstatus!,
    setfeasibilitystatus!, isfeasible, nb_ip_primal_sols, nb_lp_primal_sols, nb_lp_dual_sols,
    get_ip_primal_sols, get_lp_primal_sols, get_lp_dual_sols, get_best_ip_primal_sol,
    get_best_lp_primal_sol, get_best_lp_dual_sol, update_ip_primal_sol!, 
    update_lp_primal_sol!, update_lp_dual_sol!, add_ip_primal_sol!, add_lp_primal_sol!,
    add_lp_dual_sol!, set_ip_primal_sol!, set_lp_primal_sol!, set_lp_dual_sol!

# Algorithm's types
export AbstractOptimizationAlgorithm, TreeSearchAlgorithm, ColGenConquer, ColumnGeneration, 
       BendersConquer, BendersCutGeneration, SolveIpForm, SolveLpForm, ExactBranchingPhase, 
       OnlyRestrictedMasterBranchingPhase

end
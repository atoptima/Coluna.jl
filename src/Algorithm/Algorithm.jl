module Algorithm

using DataStructures
import MathOptInterface
import TimerOutputs

using ..Coluna, ..ColunaBase, ..MathProg, ..MustImplement, ..ColGen, ..Benders, ..AlgoAPI, ..TreeSearch, ..Branching, ..Heuristic

using Crayons, DynamicSparseArrays, Logging, Parameters, Printf, Random, Statistics, SparseArrays, LinearAlgebra

const TO = TimerOutputs
const DS = DataStructures
const MOI = MathOptInterface

const ClB = ColunaBase

import Base: push!

############################################################################################
# Incumbent primal bound handler
############################################################################################

"""
Abstract type for an utilarity structure that handles the incumbent primal bound.
"""
abstract type AbstractGlobalPrimalBoundHandler end

@mustimplement "GlobalPrimalBoundHandler" get_global_primal_bound(m::AbstractGlobalPrimalBoundHandler) = nothing
@mustimplement "GlobalPrimalBoundHandler" get_global_primal_sol(m::AbstractGlobalPrimalBoundHandler) = nothing
@mustimplement "GlobalPrimalBoundHandler" store_ip_primal_sol!(m::AbstractGlobalPrimalBoundHandler, sol) = nothing

# Utilities to build algorithms
include("utilities/optimizationstate.jl")
include("utilities/helpers.jl")

############################################################################################
# Primal bound manager
############################################################################################

"""
Default implementation of a manager of the incumbent primal bound.
This implementation does not support paralellization.
"""
struct GlobalPrimalBoundHandler <: AbstractGlobalPrimalBoundHandler
    # It only stores the IP primal solutions.
    optstate::OptimizationState
end

function GlobalPrimalBoundHandler(
    reform::Reformulation; 
    ip_primal_bound = nothing
)
    opt_state = OptimizationState(getmaster(reform))
    if !isnothing(ip_primal_bound)
        set_ip_primal_bound!(opt_state, ip_primal_bound)
    end
    return GlobalPrimalBoundHandler(opt_state)
end

get_global_primal_bound(manager::GlobalPrimalBoundHandler) = get_ip_primal_bound(manager.optstate)
get_global_primal_sol(manager::GlobalPrimalBoundHandler) = get_best_ip_primal_sol(manager.optstate)
store_ip_primal_sol!(manager::GlobalPrimalBoundHandler, sol) = add_ip_primal_sols!(manager.optstate, sol)

############################################################################################

# API on top of storage API
include("data.jl")

# Algorithm interface
include("interface.jl")

# Storage units & records implementation
include("formstorages.jl")

# Basic algorithms
include("basic/subsolvers.jl")
include("basic/solvelpform.jl")
include("basic/solveipform.jl")
include("basic/cutcallback.jl")

# Child algorithms used by conquer algorithms
include("colgenstabilization.jl")

# Column generation
include("colgen/utils.jl")
include("colgen/stabilization.jl")
include("colgen/default.jl")
include("colgen/printer.jl")
include("colgen.jl")

# Benders algorithm
include("benders/utils.jl")
include("benders/default.jl")
include("benders/printer.jl")
include("benders.jl")

# Presolve
include("presolve/helpers.jl")
include("presolve/interface.jl")
include("presolve/propagation.jl")

# Conquer
include("conquer.jl")

# Here include divide algorithms
include("branching/interface.jl")
include("branching/sbnode.jl")
include("branching/selectioncriteria.jl")
include("branching/scores.jl")
include("branching/single_var_branching.jl")
include("branching/printer.jl")
include("branching/branchingalgo.jl")

# Heuristics
include("heuristic/restricted_master.jl")

# Tree search
include("treesearch.jl")
include("treesearch/printer.jl")
include("treesearch/branch_and_bound.jl")

include("branchcutprice.jl")

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
    run!

# Algorithms
export TreeSearchAlgorithm, ColCutGenConquer, ColumnGeneration, BendersConquer, BendersCutGeneration, SolveIpForm, RestrictedMasterIPHeuristic,
    SolveLpForm, NoBranching, Branching, StrongBranching,
    FirstFoundCriterion, MostFractionalCriterion, SingleVarBranchingRule

# Algorithm's types
export AbstractOptimizationAlgorithm,
    OptimizationState

# Types of optimizers
export MoiOptimize, UserOptimizer

end

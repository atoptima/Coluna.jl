module Formulations

import BlockDecomposition
import MathOptInterface
import TimerOutputs

import ..Coluna # for NestedEnum (types.jl:210)
using ..Coluna: AbstractGlobalStrategy, Params # to be deleted
using ..Containers

using Logging
using Printf

global const MOI = MathOptInterface
global const BD = BlockDecomposition
global const TO = TimerOutputs

# TODO : clean up
# Types
export AbstractFormulation, MaxSense, MinSense, MoiOptimizer, VarMembership, 
       Variable, Constraint, AbstractObjSense, OptimizationResult, VarDict,
       ConstrDict, Id, ConstrSense, VarSense, Formulation, Reformulation, VarId,
       ConstrId, VarData, ConstrData, Incumbents, DualSolution, PrimalSolution,
       PrimalBound, DualBound, FormId, FormulationPhase, Problem, Annotations,
       Original

# Methods
export no_optimizer_builder, set_original_formulation!, create_origvars!,
       setvar!

include("counters.jl")
include("types.jl")
include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("varconstr.jl")

include("manager.jl")
include("filters.jl")
include("solsandbounds.jl")
include("optimizationresults.jl")
include("incumbents.jl")
include("buffer.jl")
include("formulation.jl")
include("optimizerwrappers.jl")
include("clone.jl")
include("reformulation.jl")
include("projection.jl")
include("problem.jl")
include("decomposition.jl")

end
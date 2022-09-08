module MathProg

import BlockDecomposition
import MathOptInterface
import TimerOutputs

using ..Coluna # for NestedEnum (types.jl:210)
using ..ColunaBase

import Base: haskey, length, iterate, diff, delete!, contains, setindex!, getindex, view

using DynamicSparseArrays, SparseArrays, Logging, Printf, LinearAlgebra

const BD = BlockDecomposition
const ClB = ColunaBase
const MOI = MathOptInterface
const TO = TimerOutputs

const MAX_NB_FORMULATIONS = typemax(Int16)

include("types.jl")
include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("bounds.jl")
include("solutions.jl")
include("buffer.jl")
include("manager.jl")
include("duties.jl")
include("formulation.jl")
include("varconstr.jl")
include("optimizerwrappers.jl")
include("clone.jl")
include("reformulation.jl")
include("projection.jl")
include("problem.jl")
include("MOIinterface.jl")

# TODO : clean up
# Types
export  MaxSense, MinSense,
        Id, ConstrSense, VarSense,
        FormId, FormulationPhase, Annotations,
        Counter, MoiObjective

# Methods
export no_optimizer_builder, set_original_formulation!,
       getid,
       enforce_integrality!, relax_integrality!,
       getobjsense, getoptimizer, getoptimizers,
       update!,
       getduty,
       computereducedrhs,
       find_owner_formulation,
       getsortuid,
       contains, setprimalbound!, get_original_formulation,
       getoriginformuid, getspsol, sync_solver!, getinner,
       get_primal_solutions, get_dual_solutions, constraint_primal

# Below this line, clean up has been done :

# Methods related to Problem
export Problem, set_initial_dual_bound!, set_initial_primal_bound!,
       get_initial_dual_bound, get_initial_primal_bound, get_optimization_target,
       set_default_optimizer_builder!

# Methods related to Reformulation
export Reformulation, getmaster, add_dw_pricing_sp!, add_benders_sep_sp!, get_dw_pricing_sps,
    set_reformulation!, get_benders_sep_sps, get_dw_pricing_sp_ub_constrid,
    get_dw_pricing_sp_lb_constrid, setmaster!

# Methods related to formulations
export AbstractFormulation, Formulation, create_formulation!, getreformulation, getvar, getvars,
    getconstr, getconstrs, getelem, getcoefmatrix, get_primal_sol_pool, getprimalsolcosts,
    getdualsolmatrix, getdualsolrhss, setvar!, setconstr!, setdualsol!,
    set_robust_constr_generator!, get_robust_constr_generators,
    setcol_from_sp_primalsol!, setcut_from_sp_dualsol!, # TODO : merge with setvar! & setconstr
    set_objective_sense!, clonevar!, cloneconstr!, clonecoeffs!, initialize_optimizer!,
    push_optimizer!, getobjconst, setobjconst!, addcustomvars!, addcustomconstrs!, 
    insert_column!, get_column_from_pool

# Duties of formulations
export Original, DwMaster, BendersMaster, DwSp, BendersSp

# Methods related to duties
export isanArtificialDuty, isaStaticDuty, isaDynamicDuty, isanOriginalRepresentatives

# Types and methods related to variables and constraints
export Variable, Constraint, VarId, ConstrId, VarMembership, ConstrMembership,
    getperencost, setperencost!, getcurcost, setcurcost!, getperenlb, getcurlb, setcurlb!,
    getperenub, getcurub, setcurub!, getperenrhs, setperenrhs!, getcurrhs, setcurrhs!, getperensense, setperensense!,
    getcursense, setcursense!, getperenkind, getcurkind, setcurkind!, getperenincval,
    getcurincval, setcurincval!, isperenactive, iscuractive, activate!, deactivate!,
    isexplicit, getname, getbranchingpriority, reset!, getreducedcost, setperenkind!

# Types & methods related to solutions & bounds
export PrimalBound, DualBound, AbstractSolution, PrimalSolution, DualSolution, ActiveBound, ObjValues,
       get_var_redcosts

# Methods related to projections
export projection_is_possible, proj_cols_on_rep

# Optimizers of formulations
export MoiOptimizer, CustomOptimizer, UserOptimizer, NoOptimizer

end

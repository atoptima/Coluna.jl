module MathProg

import BlockDecomposition
import Distributed
import MathOptInterface
import TimerOutputs

import ..Coluna # for NestedEnum (types.jl:210)
using ..Coluna: iterate # to be deleted
using ..Containers

import Base: haskey, length, iterate, diff

using Logging
using Printf

global const BD = BlockDecomposition
global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const TO = TimerOutputs

# TODO : clean up
# Types
export AbstractFormulation, MaxSense, MinSense, MoiOptimizer, VarMembership, 
       Variable, Constraint, AbstractObjSense, OptimizationResult, VarDict,
       ConstrDict, Id, ConstrSense, VarSense, Formulation, Reformulation, VarId,
       ConstrId, VarData, ConstrData, Incumbents, DualSolution, PrimalSolution,
       PrimalBound, DualBound, FormId, FormulationPhase, Problem, Annotations,
       Original, Counter, UserOptimizer, MoiObjective, PrimalSolVector

export INFEASIBLE, UNKNOWN_FEASIBILITY, FEASIBLE, OPTIMAL

# Methods
export no_optimizer_builder, set_original_formulation!, create_origvars!,
       setvar!, getid, store!, getrhs, getsense, setconstr!, getuid, getcoefmatrix,
       getvar, getvars, getconstr, getconstrs, getrecordeddata, getkind, setkind!,
       setub!, setlb!, getub, getlb, setcost!, setcurcost!,
       register_objective_sense!, optimize!, nbprimalsols, ip_gap, getdualbound,
       getprimalbound, get_ip_dual_bound, printbounds, getmaster, deactivate!, 
       enforce_integrality!, relax_integrality!, activate!, update_ip_primal_sol!,
       getobjsense, getoptimizer, getbestprimalsol, get_ip_primal_bound, get_ip_primal_sol,
       get_cur_is_active, get_cur_is_explicit, getcurdata, getbound, isbetter,
       add_primal_sol!, getresult, setdualbound!, determine_statuses, getvalue,
       isfeasible, getterminationstatus, getfeasibilitystatus, getcurrhs,
       getprimalsols, getdualsols, update_lp_primal_sol!, contains, get_dw_pricing_sp,
       _active_pricing_sp_var_, computereducedcost, isaArtificialDuty, getvarcounter,
       resetsolvalue!, setprimaldwspsol!, update_ip_dual_bound!, update_lp_dual_bound!,
       get_lp_primal_bound, diff, gap, update!, get_lp_primal_sol, getsol, 
       get_benders_sep_sp, convert_status, getduty, getbestdualsol, update_lp_dual_sol!,
       projection_is_possible, proj_cols_on_rep, get_lp_dual_bound, getperenekind,
       _active_BendSpMaster_constr_, getname, computereducedrhs, getcurlb,
       unsafe_getbestprimalsol, getcurub, setcurrhs!, getcurcost, getcost,
       _active_BendSpSlackFirstStage_var_, getconstrcounter, setprimaldualbendspsol!,
       defaultprimalboundvalue, set_lp_primal_bound!, getpereneub, _active_,
       getperenecost, update_ip_primal_bound!, getprimaldwspsolmatrix, _active_explicit_,
       _rep_of_orig_var_, getcursense, getcurkind, find_owner_formulation,
       setfeasibilitystatus!, setterminationstatus!, get_dw_pricing_sps, 
       setprimalsol!, setdualsol!, getsortuid, setcol_from_sp_primalsol!,
       get_benders_sep_sps, setcut_from_sp_dualsol!, getprimalsolmatrix

# Below this line, clean up has been done :
export reformulate!

# Parameters
const MAX_FORMULATIONS = 100
const MAX_PROCESSES = 100

include("counters.jl")
include("types.jl")
include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("varconstr.jl")

include("solsandbounds.jl")
include("manager.jl")
include("filters.jl")
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
include("MOIinterface.jl")

end

type VarMpFormIndexStatus{V<:Variable}
    variable::V
    status_in_basic_sol::Int
end

type ConstrMpFormIndexStatus{C<:Constraint}
    constraint::C
    status_in_basic_sol::Int
end

type LpBasisRecord
    name::String
    vars_in_basis::Vector{VarMpFormIndexStatus}
    constr_in_basis::Vector{ConstrMpFormIndexStatus}
end

LpBasisRecord(name::String) = LpBasisRecord(name, Vector{VarMpFormIndexStatus}(), 
                              Vector{ConstrMpFormIndexStatus}())

LpBasisRecord() = LpBasisRecord("basis")

function clear(basis::LpBasisRecord; remove_marks_in_vars=true, 
               remove_marks_in_constrs=true)::Void
               
    if remove_marks_in_vars
        for var in basis.vars_in_basis
            var.is_info_updated = false
        end
        empty!(basis.vars_in_basis)
    end

    if remove_marks_in_constrs
        for constr in constr_in_basis
            constr.is_info_updated = false
        end
        empty!(basis.constrsinbasis)
    end
    return
end

# needed for partial solution
type VariableSolInfo{V<:Variable}
    variable::V
    value::Float
end

function applyvarinfo(var_sol_info::VariableSolInfo)::Void
    variable = var_sol_info.variable
    value = var_sol_info.value
    problem = variable.problem
    updatepartialsolution(problem,variable,value)
end

# TODO: impl properly the var/constr manager
abstract type AbstractVarIndexManager end
abstract type AbstractConstrIndexManager end

type SimpleVarIndexManager <: AbstractVarIndexManager
    active_static_list::Vector{Variable}
    active_dynamic_list::Vector{Variable}
    unsuitable_static_list::Vector{Variable}
    unsuitable_dynamic_list::Vector{Variable}
end

SimpleVarIndexManager() = SimpleVarIndexManager(Vector{Variable}(),
        Vector{Variable}(), Vector{Variable}(), Vector{Variable}())

function addinvarmanager(varmanager::SimpleVarIndexManager, var::Variable)
    if var.status == Active && var.flag == 's'
        list = var_manager.active_static_list
    elseif var.status == Active && var.flag == 'd'
        list = active_dynamic_list
    elseif var.status == Unsuitable && var.flag == 's'
        list = unsuitable_static_list
    elseif var.status == Unsuitable && var.flag == 'd'
        list = inactive_dynamic_list
    else
        error("Status $(var.status) and flag $(var.flag) are not supported")
    end
    push!(list, var)
    var.index = length(list)
end

type SimpleConstrIndexManager <: AbstractConstrIndexManager
    active_static_list::Vector{Constraint}
    active_dynamic_list::Vector{Constraint}
    unsuitable_static_list::Vector{Constraint}
    unsuitable_dynamic_list::Vector{Constraint}
end

SimpleConstrIndexManager() = SimpleConstrIndexManager(Vector{Constraint}(), 
        Vector{Constraint}(), Vector{Constraint}(), Vector{Constraint}())

function addinconstrmanager(constrmanager::SimpleConstrIndexManager, 
                            constr::Constraint)
                            
    if constr.status == Active && constr.flag == 's'
        list = constr_manager.active_static_list
    elseif constr.status == Active && constr.flag == 'd'
        list = active_dynamic_list
    elseif constr.status == Unsuitable && constr.flag == 's'
        list = unsuitable_static_list
    elseif constr.status == Unsuitable && constr.flag == 'd'
        list = inactive_dynamic_list
    else
        error("Status $(constr.status) and flag $(constr.flag) are not supported")
    end
    push!(list, constr)
    constr.index = length(list)
end

abstract type Problem end

type CompactProblem{VM <: AbstractVarIndexManager, 
                    CM <: AbstractConstrIndexManager} <: Problem

    # probInfeasiblesFlag::Bool

    # objvalueordermagnitude::Float
    prob_is_built::Bool

    optimizer::MOI.AbstractOptimizer
    # primalFormulation::LPform

    var_manager::VM
    constr_manager::CM

    in_primal_lp_sol::Set{Variable}
    # inprimalipsol::Set{Variable}
    non_zero_red_cost_vars::Set{Variable}
    in_dual_sol::Set{Constraint}

    partial_solution_value::Float
    partial_solution::Dict{Variable,Float}

    # nbofrecordedsol::Int
    recorded_sol::Vector{Solution}

    # needed for new preprocessing
    preprocessed_constrs_list::Vector{Constraint}
    preprocessed_vars_list::Vector{Variable}

    counter::VarConstrCounter
    var_constr_vec::Vector{VarConstr}

    # added for more efficiency and to fix bug
    # after columns are cleaned we can t ask for red costs
    # before the MIPSolver solves the master again.
    # It is put to true in retrieveRedCosts()
    # It is put to false in resetSolution()
    is_retrieved_red_costs::Bool
end

function Problem{VM,CM}(useroptimizer::MOI.AbstractOptimizer) 
        where {VM <: AbstractVarIndexManager, CM <: AbstractConstrIndexManager}

    optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(), 
                                      useroptimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    MOI.set!(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(),f)
    MOI.set!(optimizer, MOI.ObjectiveSense(), MOI.MinSense)

    Problem(false, optimizer, VM(), CM(), Set{Variable}(), Set{Variable}(), 
            Set{Constraint}(), 0.0, Dict{Variable,Float}(), Vector{Solution}(), 
            Vector{Constraint}(), Vector{Variable}(), VarConstrCounter(0), 
            Vector{VarConstr}(), false)
end

const SimpleProblem = Problem{SimpleVarIndexManager,SimpleConstrIndexManager}

### addvariable changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the variable
function addvariable(problem::Problem, var::Variable)
    addinvarmanager(problem.varmanager, var)
    var.moiindex = MOI.addvariable!(problem.optimizer)
    push!(problem.varconstrvec, var)
    MOI.modify!(problem.optimizer, 
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), 
                MOI.ScalarCoefficientChange{Float}(var.moiindex, var.costrhs))
    MOI.addconstraint!(problem.optimizer, MOI.SingleVariable(var.moiindex), 
                       MOI.Interval(var.lowerbound, var.upperbound))
end

### addconstraint changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the constraint
function addconstraint(problem::Problem, constr::Constraint)
    addinconstrmanager(problem.constrmanager, constr)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    constr.moiindex = MOI.addconstraint!(problem.optimizer, f, 
            constr.settype(constr.costrhs))
    push!(problem.varconstrvec, constr)
end

function addmembership(var::Variable, constr::Constraint, coef::Float)
    var.membercoefmap[var.vc_ref] = coef
    constr.membercoefmap[constr.vc_ref] = coef
    MOI.modify!(var.problem.optimizer,  constr.moiindex, 
                MOI.ScalarCoefficientChange{Float}(var.moiindex, coef))
end

function addmembership(var::SubProbVar, constr::MasterConstr, coef::Float)
    var.masterconstrcoefmap[var.vc_ref] = coef
    constr.subprobvarcoefmap[constr.vc_ref] = coef
end

# function addmembership(var::MasterVar, constr::MasterConstr, coef::Float)
#     var.membercoefmap[var.vc_ref] = coef
#     constr.membercoefmap[constr.vc_ref] = coef
#     MOI.modify!(var.problem.optimizer,  constr.moiindex, 
#                 MOI.ScalarCoefficientChange{Float}(var.moiindex, coef))
# end

function optimize(problem::Problem)
    MOI.optimize!(problem.optimizer)
end

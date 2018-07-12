
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

function apply_var_info(var_sol_info::VariableSolInfo)::Void
    variable = var_sol_info.variable
    value = var_sol_info.value
    problem = variable.problem
    update_partial_solution(problem,variable,value)
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

function add_in_var_manager(var_manager::SimpleVarIndexManager, var::Variable)
    if var.status == Active && var.flag == 's'
        list = var_manager.active_static_list
    elseif var.status == Active && var.flag == 'd'
        list = var_manager.active_dynamic_list
    elseif var.status == Unsuitable && var.flag == 's'
        list = var_manager.unsuitable_static_list
    elseif var.status == Unsuitable && var.flag == 'd'
        list = var_manager.unsuitable_dynamic_list
    else
        error("Status $(var.status) and flag $(var.flag) are not supported")
    end
    push!(list, var)
end

type SimpleConstrIndexManager <: AbstractConstrIndexManager
    active_static_list::Vector{Constraint}
    active_dynamic_list::Vector{Constraint}
    unsuitable_static_list::Vector{Constraint}
    unsuitable_dynamic_list::Vector{Constraint}
end

SimpleConstrIndexManager() = SimpleConstrIndexManager(Vector{Constraint}(),
        Vector{Constraint}(), Vector{Constraint}(), Vector{Constraint}())

function add_in_constr_manager(constr_manager::SimpleConstrIndexManager,
                            constr::Constraint)

    if constr.status == Active && constr.flag == 's'
        list = constr_manager.active_static_list
    elseif constr.status == Active && constr.flag == 'd'
        list = constr_manager.active_dynamic_list
    elseif constr.status == Unsuitable && constr.flag == 's'
        list = constr_manager.unsuitable_static_list
    elseif constr.status == Unsuitable && constr.flag == 'd'
        list = constr_manager.unsuitable_dynamic_list
    else
        error("Status $(constr.status) and flag $(constr.flag) are not supported")
    end
    push!(list, constr)
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

function CompactProblem{VM,CM}(useroptimizer::MOI.AbstractOptimizer
        ) where {VM <: AbstractVarIndexManager, CM <: AbstractConstrIndexManager}

    optimizer = MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                      useroptimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    MOI.set!(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(),f)
    MOI.set!(optimizer, MOI.ObjectiveSense(), MOI.MinSense)

    CompactProblem(false, optimizer, VM(), CM(), Set{Variable}(), Set{Variable}(),
            Set{Constraint}(), 0.0, Dict{Variable,Float}(), Vector{Solution}(),
            Vector{Constraint}(), Vector{Variable}(), VarConstrCounter(0),
            Vector{VarConstr}(), false)
end

const SimpleCompactProblem = CompactProblem{SimpleVarIndexManager,SimpleConstrIndexManager}

### addvariable changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the variable
function add_variable(problem::Problem, var::Variable)
    add_in_var_manager(problem.var_manager, var)
    var.moi_index = MOI.addvariable!(problem.optimizer)
    MOI.modify!(problem.optimizer,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                MOI.ScalarCoefficientChange{Float}(var.moi_index, var.cost_rhs))
    MOI.addconstraint!(problem.optimizer, MOI.SingleVariable(var.moi_index),
                       MOI.Interval(var.lower_bound, var.upper_bound))
end

### addconstraint changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the constraint
function add_constraint(problem::Problem, constr::Constraint)
    add_in_constr_manager(problem.constr_manager, constr)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    constr.moi_index = MOI.addconstraint!(problem.optimizer, f,
            constr.set_type(constr.cost_rhs))
end

function add_membership(var::Variable, constr::Constraint, coef::Float)
    var.member_coef_map[constr] = coef
    constr.member_coef_map[var] = coef
    MOI.modify!(var.problem.optimizer,  constr.moi_index,
                MOI.ScalarCoefficientChange{Float}(var.moi_index, coef))
end

function add_membership(var::SubprobVar, constr::MasterConstr, coef::Float)
    var.master_constr_coef_map[constr] = coef
    constr.subprob_var_coef_map[var] = coef
end

function add_membership(var::MasterVar, constr::MasterConstr, coef::Float)
    var.member_coef_map[constr] = coef
    constr.member_coef_map[var] = coef
    MOI.modify!(var.problem.optimizer,  constr.moi_index,
                MOI.ScalarCoefficientChange{Float}(var.moi_index, coef))
end

function optimize(problem::Problem)
    MOI.optimize!(problem.optimizer)
end

# TODO: implement updates in formulation
function add_in_form(problem, vars_to_add::Variable)
end

function del_in_form(problem, vars_to_del::Variable)
end

function update_bounds_in_form(problem, vars_to_update_bounds)
end

function update_costs_in_form(problem, vars_to_update_cost)
end

function add_in_form(problem, constrs_to_add::Constraint)
end

function del_in_form(problem, constrs_to_del::Constraint)
end

function update_rhs_in_form(problem, constrs_to_change_rhs)
end

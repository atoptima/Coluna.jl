
mutable struct VarMpFormStatus{V<:Variable}
    variable::V
    status_in_basic_sol::Int
end

mutable struct ConstrMpFormStatus{C<:Constraint}
    constraint::C
    status_in_basic_sol::Int
end

mutable struct LpBasisRecord
    name::String
    vars_in_basis::Vector{VarMpFormStatus}
    constr_in_basis::Vector{ConstrMpFormStatus}
end


LpBasisRecord(name::String) = LpBasisRecord(name, Vector{VarMpFormStatus}(),
                              Vector{ConstrMpFormStatus}())

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
mutable struct VariableSolInfo{V<:Variable}
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

mutable struct SimpleVarIndexManager <: AbstractVarIndexManager
    active_static_list::Vector{Variable}
    active_dynamic_list::Vector{Variable}
    unsuitable_static_list::Vector{Variable}
    unsuitable_dynamic_list::Vector{Variable}
end

SimpleVarIndexManager() = SimpleVarIndexManager(Vector{Variable}(),
        Vector{Variable}(), Vector{Variable}(), Vector{Variable}())

function add_var_in_manager(var_manager::SimpleVarIndexManager, var::Variable)
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

mutable struct SimpleConstrIndexManager <: AbstractConstrIndexManager
    active_static_list::Vector{Constraint}
    active_dynamic_list::Vector{Constraint}
    unsuitable_static_list::Vector{Constraint}
    unsuitable_dynamic_list::Vector{Constraint}
end

SimpleConstrIndexManager() = SimpleConstrIndexManager(Vector{Constraint}(),
        Vector{Constraint}(), Vector{Constraint}(), Vector{Constraint}())

function add_constr_in_manager(constr_manager::SimpleConstrIndexManager,
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

function remove_from_constr_manager(constr_manager::SimpleConstrIndexManager,
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
    idx = findfirst(list, constr)
    deleteat!(list, idx)
end

mutable struct ProblemCounter
    value::Int
end

function increment_counter(counter::ProblemCounter)
    counter.value += 1
    return counter.value
end

abstract type Problem end

mutable struct CompactProblem{VM <: AbstractVarIndexManager,
                    CM <: AbstractConstrIndexManager} <: Problem

    prob_ref::Int
    # probInfeasiblesFlag::Bool

    # objvalueordermagnitude::Float
    prob_is_built::Bool

    optimizer::Union{MOI.AbstractOptimizer, Nothing}
    # primalFormulation::LPform

    var_manager::VM
    constr_manager::CM

    ### Current solutions
    obj_val::Float
    obj_bound::Float # Dual bound in LP, and "pruning" bound for MIP
    in_primal_lp_sol::Set{Variable}
    non_zero_red_cost_vars::Set{Variable}
    in_dual_lp_sol::Set{Constraint}
    partial_solution_value::Float
    partial_solution::Dict{Variable,Float}

    # Recorded solutions, may be integer or not
    primal_sols::Vector{PrimalSolution}
    dual_sols::Vector{DualSolution}

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

function CompactProblem{VM,CM}(prob_counter::ProblemCounter,
                               vc_counter::VarConstrCounter) where {
    VM <: AbstractVarIndexManager,
    CM <: AbstractConstrIndexManager}

    optimizer = nothing

    primal_vec = Vector{PrimalSolution}([PrimalSolution()])
    dual_vec = Vector{DualSolution}([DualSolution()])

    CompactProblem(increment_counter(prob_counter), false, optimizer, VM(), CM(),
                   Inf, -Inf, Set{Variable}(), Set{Variable}(), Set{Constraint}(),
                   0.0, Dict{Variable,Float}(), primal_vec, dual_vec,
                   Vector{Constraint}(), Vector{Variable}(),
                   vc_counter, Vector{VarConstr}(), false)
end

SimpleCompactProblem = CompactProblem{SimpleVarIndexManager,SimpleConstrIndexManager}

function initialize_problem_optimizer(problem::CompactProblem,
                                      optimizer::MOI.AbstractOptimizer)
    optimizer = MOIU.MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                           optimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MinSense)
    problem.optimizer = optimizer
end

function set_optimizer_obj(problem::CompactProblem,  
                           new_obj::Dict{V,Float}) where V <: Variable

    # TODO add a small checker function for this redundant if bloc
    if problem.optimizer == nothing
        error("The problem has no optimizer attached")
    end
    vec = [MOI.ScalarAffineTerm(cost, var.moi_index) for (var, cost) in new_obj]
    objf = MOI.ScalarAffineFunction(vec, 0.0)    
    MOI.set(problem.optimizer, 
             MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float}}(), objf)
end

function retreive_primal_sol(problem::CompactProblem)
    ## Store it in problem.primal_sols
    if problem.optimizer == nothing
        error("The problem has no optimizer attached")
    end
    problem.obj_val = MOI.get(problem.optimizer, MOI.ObjectiveValue())
    @logmsg LogLevel(4) string("Objective value: ", problem.obj_val)
    var_list = problem.var_manager.active_static_list
    new_sol = Dict{Variable, Float}()
    new_obj_val = MOI.get(problem.optimizer, MOI.ObjectiveValue())
    for var_idx in 1:length(var_list)
        var = var_list[var_idx]
        var.val = MOI.get(problem.optimizer, MOI.VariablePrimal(), 
                          var.moi_index)
        @logmsg LogLevel(4) string("Var ", var.name, " = ", var.val)
        if var.val > 0.0
            push!(problem.in_primal_lp_sol, var)
            new_sol[var] = var.val
        end
    end
    push!(problem.primal_sols, PrimalSolution(new_obj_val, new_sol))
end

function retreive_dual_sol(problem::CompactProblem)
    optimizer = problem.optimizer
    if optimizer == nothing
        error("The problem has no optimizer attached")
    end
    # TODO check if supported by solver
    # problem.obj_bound = MOI.get(optimizer, MOI.ObjectiveBound())
    try 
        if MOI.get(optimizer, MOI.DualStatus()) != MOI.FeasiblePoint
            return
        end
        constr_list = problem.constr_manager.active_static_list
        new_sol = Dict{Constraint, Float}()
        for constr_idx in 1:length(constr_list)
            constr = constr_list[constr_idx]
            constr.val = MOI.get(optimizer, MOI.ConstraintDual(),
                                 constr.moi_index)  
            @logmsg LogLevel(4) string("Constr dual ", constr.name, " = ",
                                       constr.val)
            @logmsg LogLevel(4) string("Constr primal ", constr.name, " = ", 
                    MOI.get(optimizer, MOI.ConstraintPrimal(), constr.moi_index))
            if constr.val != 0 # TODO use a tolerance
                push!(problem.in_dual_lp_sol, constr)
                new_sol[constr] = constr.val
            end
        end
        push!(problem.dual_sols, DualSolution(-Inf, new_sol)) #TODO get objbound
    catch
        @warn "Optimizer $(typeof(optimizer)) doesn't have a dual status"
    end    
end

function retreive_solution(problem::CompactProblem)
    retreive_primal_sol(problem)
    retreive_dual_sol(problem)
end

mutable struct ExtendedProblem <: Problem
    master_problem::CompactProblem # restricted master in DW case.
    pricing_vect::Vector{Problem}
    separation_vect::Vector{Problem}
    params::Params
    counter::VarConstrCounter
    solution::PrimalSolution
    primal_inc_bound::Float
    dual_inc_bound::Float
    subtree_size_by_depth::Int
end

function ExtendedProblemConstructor(prob_counter::ProblemCounter,
        vc_counter::VarConstrCounter,
        params::Params, primal_inc_bound::Float,
        dual_inc_bound::Float)

    master_problem = SimpleCompactProblem(prob_counter, vc_counter)
    return ExtendedProblem(master_problem, Problem[], Problem[],
                           params, vc_counter, PrimalSolution(),
                           params.cut_up, params.cut_lo, 0)
end

# Iterates through each problem in extended_problem,
# check its index and call function
# initialize_problem_optimizer(index, optimizer), using the dictionary
function initialize_problem_optimizer(extended_problem::ExtendedProblem,
         problemidx_optimizer_map::Dict{Int,MOI.AbstractOptimizer})

    initialize_problem_optimizer(extended_problem.master_problem,
         problemidx_optimizer_map[extended_problem.master_problem.prob_ref])

    for problem in extended_problem.pricing_vect
        initialize_problem_optimizer(problem,
              problemidx_optimizer_map[problem.prob_ref])
    end

    for problem in extended_problem.separation_vect
        initialize_problem_optimizer(problem,
              problemidx_optimizer_map[problem.prob_ref])
    end
end

function sol_is_integer(sol::Dict{Variable, Float}, tolerance::Float)
    for var_val in sol
        if (!is_value_integer(var_val.second, tolerance)            
                && (var_val.first.vc_type == 'I' || var_val.first.vc_type == 'B'))
            println("Sol is fractional.")
            return false
        end
    end
    println("Solution is integer!")
    return true
end

### addvariable changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the variable
function add_variable(problem::Problem, var::Variable)
    add_var_in_manager(problem.var_manager, var)
    if problem.optimizer != nothing
        var.moi_index = MOI.add_variable(problem.optimizer)    
        # TODO set variable type
        add_bounds = true
        if var.vc_type == 'B'
            if var.lower_bound > 0.0 
                var.lower_bound == 1.0
            elseif var.upper_bound < 1.0 
                var.upper_bound == 0.0
            else
                MOI.add_constraint(problem.optimizer, 
                               MOI.SingleVariable(var.moi_index), MOI.ZeroOne())
                add_bounds = false
            end
        elseif var.vc_type == 'I'
            MOI.add_constraint(problem.optimizer, 
                               MOI.SingleVariable(var.moi_index), MOI.Integer())
        end
        
        MOI.modify(problem.optimizer,
                MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
                MOI.ScalarCoefficientChange{Float}(var.moi_index, var.cost_rhs))
        
        if add_bounds
            MOI.add_constraint(problem.optimizer, 
                    MOI.SingleVariable(var.moi_index),
                    MOI.Interval(var.lower_bound, var.upper_bound))
        end
    end    
end

function add_variable(problem::Problem, col::MasterColumn)
    @callsuper add_variable(problem, col::Variable)
    for (var, val) in col.solution.var_val_map
        for (constr, coef) in var.master_constr_coef_map
            add_membership(problem, col, constr, val * coef)
        end
    end
end

### addconstraint changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the constraint
function add_constraint(problem::Problem, constr::Constraint)
    add_constr_in_manager(problem.constr_manager, constr)
    if problem.optimizer != nothing        
        f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float}[], 0.0)
        constr.moi_index = MOI.add_constraint(problem.optimizer, f,
                constr.set_type(constr.cost_rhs))
    end
end

function add_full_constraint(problem::Problem, constr::BranchConstr)
    add_constr_in_manager(problem.constr_manager, constr)
    terms = MOI.ScalarAffineTerm{Float}[]
    for var_val in constr.member_coef_map
        push!(terms, MOI.ScalarAffineTerm{Float}(var_val.second, var_val.first.moi_index))
    end
    if problem.optimizer != nothing
        f = MOI.ScalarAffineFunction(terms, 0.0)
        constr.moi_index = MOI.add_constraint(problem.optimizer, f,
                constr.set_type(constr.cost_rhs))
    end
end

function delete_constraint(problem::Problem, constr::BranchConstr)
    ### When deleting a constraint, its MOI index becomes invalid
    remove_from_constr_manager(problem.constr_manager, constr)
    if problem.optimizer != nothing
        MOI.delete!(problem.optimizer, constr.moi_index)
        constr.moi_index = MOI.ConstraintIndex{MOI.ScalarAffineFunction, 
                                               constr.set_type}(-1)
    end
end

function add_membership(problem::Problem, var::Variable, constr::Constraint,
        coef::Float)
    var.member_coef_map[constr] = coef
    constr.member_coef_map[var] = coef
    if problem.optimizer != nothing
        MOI.modify(problem.optimizer, constr.moi_index,
                    MOI.ScalarCoefficientChange{Float}(var.moi_index, coef))
    end
end

function add_membership(problem::Problem, var::SubprobVar, constr::MasterConstr,
        coef::Float)
    var.master_constr_coef_map[constr] = coef
    constr.subprob_var_coef_map[var] = coef
end

function add_membership(problem::Problem, var::MasterVar, constr::MasterConstr,
        coef::Float)
    var.member_coef_map[constr] = coef
    constr.member_coef_map[var] = coef
    if problem.optimizer != nothing
        MOI.modify(problem.optimizer, constr.moi_index,
                    MOI.ScalarCoefficientChange{Float}(var.moi_index, coef))
    end
end

function optimize(problem::Problem)
    if problem.optimizer == nothing
        error("The problem has no optimizer attached")
    end
    
    MOI.optimize!(problem.optimizer)
    status = MOI.get(problem.optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(4) string("Optimization finished with status: ", status)

    if MOI.get(problem.optimizer, MOI.ResultCount()) >= 1
        retreive_solution(problem)
    else
        println("Solver has no result to show.")
    end

    return status
end

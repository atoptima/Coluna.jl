
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
               remove_marks_in_constrs=true)::Nothing

    if remove_marks_in_vars
        for var in basis.vars_in_basis
            var.variable.is_info_updated = false
        end
        empty!(basis.vars_in_basis)
    end

    if remove_marks_in_constrs
        for constr in basis.constr_in_basis
            constr.constraint.is_info_updated = false
        end
        empty!(basis.constr_in_basis)
    end
    return
end

# needed for partial solution
mutable struct VariableSolInfo{V<:Variable}
    variable::V
    value::Float
end

function apply_var_info(var_sol_info::VariableSolInfo)::Nothing
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

function get_list(var_manager::SimpleVarIndexManager, status::VCSTATUS, flag::Char)
    if status == Active && flag in['s', 'a']
        list = var_manager.active_static_list
    elseif status == Active && flag == 'd'
        list = var_manager.active_dynamic_list
    elseif status == Unsuitable && flag in['s', 'a']
        list = var_manager.unsuitable_static_list
    elseif status == Unsuitable && flag == 'd'
        list = var_manager.unsuitable_dynamic_list
    else
        error("Status $(status) and flag $(flag) are not supported")
    end
    return list
end

function add_var_in_manager(var_manager::SimpleVarIndexManager, var::Variable)
    list = get_list(var_manager, var.status, var.flag)
    push!(list, var)
end

function remove_from_var_manager(var_manager::SimpleVarIndexManager,
                                 var::Variable)
    list = get_list(var_manager, var.status, var.flag)
    idx = findfirst(x->x==var, list)
    deleteat!(list, idx)
end

mutable struct SimpleConstrIndexManager <: AbstractConstrIndexManager
    active_static_list::Vector{Constraint}
    active_dynamic_list::Vector{Constraint}
    unsuitable_static_list::Vector{Constraint}
    unsuitable_dynamic_list::Vector{Constraint}
end

SimpleConstrIndexManager() = SimpleConstrIndexManager(Vector{Constraint}(),
        Vector{Constraint}(), Vector{Constraint}(), Vector{Constraint}())

function get_list(constr_manager::SimpleConstrIndexManager,
                  status::VCSTATUS, flag::Char)
    if status == Active && flag == 's'
        list = constr_manager.active_static_list
    elseif status == Active && flag == 'd'
        list = constr_manager.active_dynamic_list
    elseif status == Unsuitable && flag == 's'
        list = constr_manager.unsuitable_static_list
    elseif status == Unsuitable && flag == 'd'
        list = constr_manager.unsuitable_dynamic_list
    else
        error("Status $(status) and flag $(flag) are not supported")
    end
    return list
end

function add_constr_in_manager(constr_manager::SimpleConstrIndexManager,
                               constr::Constraint)
    list = get_list(constr_manager, constr.status, constr.flag)
    push!(list, constr)
end

function remove_from_constr_manager(constr_manager::SimpleConstrIndexManager,
        constr::Constraint)
    list = get_list(constr_manager, constr.status, constr.flag)
    idx = findfirst(x->x==constr, list)
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

###########################
##### CompactProblem ######
###########################

mutable struct CompactProblem{VM <: AbstractVarIndexManager,
                    CM <: AbstractConstrIndexManager} <: Problem

    prob_ref::Int
    # probInfeasiblesFlag::Bool

    # objvalueordermagnitude::Float
    prob_is_built::Bool

    is_relaxed::Bool
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

    CompactProblem(increment_counter(prob_counter), false, false, optimizer,
                   VM(), CM(), Inf, -Inf,
                   Set{Variable}(), Set{Variable}(), Set{Constraint}(),
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
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
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

function fill_primal_sol(problem::CompactProblem, sol::Dict{Variable, Float},
                         var_list::Vector{Variable}, optimizer, update_problem)

    for var_idx in 1:length(var_list)
        var = var_list[var_idx]
        var.val = MOI.get(optimizer, MOI.VariablePrimal(),
                          var.moi_index)
        @logmsg LogLevel(-4) string("Var ", var.name, " = ", var.val)
        if var.val > 0.0
            if update_problem
                push!(problem.in_primal_lp_sol, var)
            end
            sol[var] = var.val
        end
    end
end

function retrieve_primal_sol(problem::CompactProblem;
        optimizer = problem.optimizer, update_problem = true)
    ## Store it in problem.primal_sols
    if optimizer == nothing
        error("The problem has no optimizer attached")
    end
    if update_problem
        problem.obj_val = MOI.get(optimizer, MOI.ObjectiveValue())
    end
    @logmsg LogLevel(-4) string("Objective value: ", problem.obj_val)
    new_sol = Dict{Variable, Float}()
    new_obj_val = MOI.get(optimizer, MOI.ObjectiveValue())
    fill_primal_sol(problem, new_sol, problem.var_manager.active_static_list,
                    optimizer, update_problem)
    fill_primal_sol(problem, new_sol, problem.var_manager.active_dynamic_list,
                    optimizer, update_problem)
    primal_sol = PrimalSolution(new_obj_val, new_sol)
    if update_problem
        push!(problem.primal_sols, primal_sol)
    end
    return primal_sol
end

function retrieve_dual_sol(problem::CompactProblem;
        optimizer = problem.optimizer, update_problem = true)

    if optimizer == nothing
        error("The problem has no optimizer attached")
    end
    # TODO check if supported by solver
    # problem.obj_bound = MOI.get(optimizer, MOI.ObjectiveBound())
    try
        if MOI.get(optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
            return nothing
        end
        constr_list = problem.constr_manager.active_static_list
        constr_list = vcat(constr_list, problem.constr_manager.active_dynamic_list)
        new_sol = Dict{Constraint, Float}()
        for constr_idx in 1:length(constr_list)
            constr = constr_list[constr_idx]
            constr.val = MOI.get(optimizer, MOI.ConstraintDual(),
                                 constr.moi_index)
            @logmsg LogLevel(-4) string("Constr dual ", constr.name, " = ",
                                       constr.val)
            @logmsg LogLevel(-4) string("Constr primal ", constr.name, " = ",
                    MOI.get(optimizer, MOI.ConstraintPrimal(), constr.moi_index))
            if constr.val != 0 # TODO use a tolerance
                if update_problem
                    push!(problem.in_dual_lp_sol, constr)
                end
                new_sol[constr] = constr.val
            end
        end
        dual_sol = DualSolution(-Inf, new_sol)
        if update_problem
            push!(problem.dual_sols, dual_sol) #TODO get objbound
        end
        return dual_sol
    catch
        @warn "Optimizer $(typeof(optimizer)) doesn't have a dual status"
        return nothing
    end
end

function retrieve_solution(problem::CompactProblem)
    retrieve_primal_sol(problem)
    retrieve_dual_sol(problem)
end

function is_sol_integer(sol::Dict{Variable, Float}, tolerance::Float)
    for var_val in sol
        if (!is_value_integer(var_val.second, tolerance)
                && (var_val.first.vc_type == 'I' || var_val.first.vc_type == 'B'))
            @logmsg LogLevel(-2) "Sol is fractional."
            return false
        end
    end
    @logmsg LogLevel(-4) "Solution is integer!"
    return true
end

### addvariable changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the variable
function add_variable(problem::CompactProblem, var::Variable,
                      update_moi::Bool)
    @logmsg LogLevel(-4) "adding Variable $var"
    add_var_in_manager(problem.var_manager, var)
    @assert var.prob_ref == -1
    var.prob_ref = problem.prob_ref
    if update_moi
        @assert problem.optimizer != nothing
        add_variable_in_optimizer(problem.optimizer, var, problem.is_relaxed)
    end
end

function add_variable_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                   var::Variable, is_relaxed::Bool)

    create_moi_index(optimizer, var)
    update_cost_in_optimizer(optimizer, var)
    !is_relaxed && enforce_type_in_optimizer(optimizer, var)
    if (var.vc_type != 'B' || is_relaxed)
        enforce_initial_bounds_in_optimizer(optimizer, var)
    end
end

function update_moi_membership(optimizer::MOI.AbstractOptimizer,
                               col::MasterColumn)
    for constr_coef in col.member_coef_map
        update_moi_membership(optimizer, col, constr_coef[1], constr_coef[2])
    end
end

####################################################################
########################### New functions ##########################
####################################################################

function create_moi_index(optimizer::MOI.AbstractOptimizer, var::Variable)
    var.moi_index = MOI.add_variable(optimizer)
end

function remove_var_from_optimizer(optimizer::MOI.AbstractOptimizer,
                                   var::Variable)
    MOI.delete(optimizer, var.moi_index)
    var.moi_index = MOI.VariableIndex(-1)
end

function update_cost_in_optimizer(optimizer::MOI.AbstractOptimizer, var::Variable)
    MOI.modify(optimizer,
               MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
               MOI.ScalarCoefficientChange{Float}(var.moi_index, var.cost_rhs))
end

function enforce_initial_bounds_in_optimizer(
    optimizer::MOI.AbstractOptimizer, var::Variable)
    MOI.add_constraint(optimizer,
                       MOI.SingleVariable(var.moi_index),
                       MOI.Interval(var.lower_bound, var.upper_bound))
end

function enforce_type_in_optimizer(
    optimizer::MOI.AbstractOptimizer, var::Variable)
    if var.vc_type == 'B'
        MOI.add_constraint(optimizer,
                           MOI.SingleVariable(var.moi_index), MOI.ZeroOne())
    elseif var.vc_type == 'I'
        MOI.add_constraint(optimizer,
                           MOI.SingleVariable(var.moi_index), MOI.Integer())
    end
end

function add_constr_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                 constr::Constraint)
    terms = compute_constr_moi_terms(constr)
    f = MOI.ScalarAffineFunction(terms, 0.0)
    constr.moi_index = MOI.add_constraint(
        optimizer, f, constr.set_type(constr.cost_rhs)
    )
end

function remove_constr_from_optimizer(optimizer::MOI.AbstractOptimizer,
                                      constr::Constraint)

    MOI.delete(optimizer, constr.moi_index)
    constr.moi_index = MOI.ConstraintIndex{MOI.ScalarAffineFunction,
                                           constr.set_type}(-1)
end

function update_var_status(problem::CompactProblem,
                           var::Variable, new_status::VCSTATUS)
    if var.status == new_status
        return
    end
    remove_from_var_manager(problem.var_manager, var)
    var.status = new_status
    add_var_in_manager(problem.var_manager, var)
end

function update_constr_status(problem::CompactProblem,
                              constr::Constraint, new_status::VCSTATUS)
    if constr.status == new_status
        return
    end
    remove_from_constr_manager(problem.constr_manager, constr)
    constr.status = new_status
    add_constr_in_manager(problem.constr_manager, constr)
end

### addconstraint changes problem and MOI cachingOptimizer.model_cache
### and sets the index of the constraint
function add_constraint(problem::CompactProblem, constr::Constraint;
                        update_moi = false)
    @logmsg LogLevel(-4) "adding Constraint $constr"
    @assert constr.prob_ref == -1# || constr.prob_ref == problem.prob_ref
    constr.prob_ref = problem.prob_ref
    add_constr_in_manager(problem.constr_manager, constr)
    if update_moi
        @assert problem.optimizer != nothing
        add_constr_in_optimizer(problem.optimizer, constr)
    end
end

function compute_constr_moi_terms(constr::Constraint)
    return [
        MOI.ScalarAffineTerm{Float}(var_val.second, var_val.first.moi_index)
        for var_val in constr.member_coef_map if var_val.first.status == Active
    ]
end

function load_problem_in_optimizer(problem::CompactProblem,
        optimizer::MOI.AbstractOptimizer, is_relaxed::Bool)

    for var in problem.var_manager.active_static_list
        add_variable_in_optimizer(optimizer, var, is_relaxed)
    end
    for var in problem.var_manager.active_dynamic_list
        add_variable_in_optimizer(optimizer, var, is_relaxed)
    end
    for constr in problem.constr_manager.active_static_list
        add_constr_in_optimizer(optimizer, constr)
    end
    for constr in problem.constr_manager.active_dynamic_list
        add_constr_in_optimizer(optimizer, constr)
    end
end

function delete_constraint(problem::CompactProblem, constr::MasterBranchConstr)
    ### When deleting a constraint, its MOI index becomes invalid
    remove_from_constr_manager(problem.constr_manager, constr)
    constr.prob_ref = -1
    if problem.optimizer != nothing
        remove_constr_from_optimizer(problem.optimizer, constr)
    end
end

function update_moi_membership(optimizer::MOI.AbstractOptimizer, var::Variable,
                               constr::Constraint, coef::Float)
    MOI.modify(optimizer, constr.moi_index,
               MOI.ScalarCoefficientChange{Float}(var.moi_index, coef))
end

function add_membership(var::Variable, constr::Constraint, coef::Float;
                        optimizer::T = nothing) where T <: Union{MOI.AbstractOptimizer, Nothing}

    @logmsg LogLevel(-4) "add_membership : Variable = $var, Constraint = $constr"
    var.member_coef_map[constr] = coef
    constr.member_coef_map[var] = coef
    if optimizer != nothing
        update_moi_membership(optimizer, var, constr, coef)
    end
end

function add_membership(var::SubprobVar, constr::MasterConstr, coef::Float;
                        optimizer::T = nothing) where T <: Union{MOI.AbstractOptimizer, Nothing}
    @logmsg LogLevel(-4) "add_membership : SubprobVar = $var, MasterConstraint = $constr"
    var.master_constr_coef_map[constr] = coef
    constr.subprob_var_coef_map[var] = coef
end

# The only interest of having this function is the specific printing
function add_membership(var::MasterVar, constr::MasterConstr, coef::Float;
                        optimizer::T = nothing) where T <: Union{MOI.AbstractOptimizer, Nothing}

    @logmsg LogLevel(-4) "add_membership : MasterVar = $var, MasterConstr = $constr"
    var.member_coef_map[constr] = coef
    constr.member_coef_map[var] = coef
    if optimizer != nothing
        update_moi_membership(optimizer, var, constr, coef)
    end
end

# Updates the problem with the primal/dual sols
function optimize!(problem::CompactProblem)
    if problem.optimizer == nothing
        error("The problem has no optimizer attached")
    end

    MOI.optimize!(problem.optimizer)
    status = MOI.get(problem.optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)

    if MOI.get(problem.optimizer, MOI.ResultCount()) >= 1
        retrieve_solution(problem)
    else
        @logmsg LogLevel(-4) string("Solver has no result to show.")
    end

    return status
end

# does not modify problem but returns the primal/dual sols instead
function optimize(problem::CompactProblem, optimizer::MOI.AbstractOptimizer)
    MOI.optimize!(optimizer)
    status = MOI.get(optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)

    if MOI.get(optimizer, MOI.ResultCount()) >= 1
        primal_sol = retrieve_primal_sol(problem,
                optimizer = optimizer, update_problem = false)
        dual_sol = retrieve_dual_sol(problem,
                optimizer = optimizer, update_problem = false)
    else
        @logmsg LogLevel(-4) string("Solver has no result to show.")
    end

    return (status, primal_sol, dual_sol)
end

###########################
##### ExtendedProblem #####
###########################

mutable struct ExtendedProblem <: Problem
    master_problem::CompactProblem # restricted master in DW case.
    artificial_global_pos_var::MasterVar
    artificial_global_neg_var::MasterVar
    pricing_vect::Vector{Problem}
    pricing_convexity_lbs::Dict{Problem, MasterConstr}
    pricing_convexity_ubs::Dict{Problem, MasterConstr}
    separation_vect::Vector{Problem}
    params::Params
    counter::VarConstrCounter
    solution::PrimalSolution
    primal_inc_bound::Float
    dual_inc_bound::Float
    subtree_size_by_depth::Int
    timer_output::TimerOutputs.TimerOutput
    problem_ref_to_problem::Dict{Int,Problem}
end

function ExtendedProblem(prob_counter::ProblemCounter,
        vc_counter::VarConstrCounter,
        params::Params, primal_inc_bound::Float,
        dual_inc_bound::Float)

    master_problem = SimpleCompactProblem(prob_counter, vc_counter)
    master_problem.is_relaxed = true

    #TODO change type of art_vars 's' -> 'a', needed for pure phase 1
    artificial_global_pos_var = MasterVar(vc_counter, "art_glob_pos",
            1000000.0, 'P', 'C', 'a', 'U', 1.0, 0.0, Inf)
    artificial_global_neg_var = MasterVar(vc_counter, "art_glob_neg",
            -1000000.0, 'N', 'C', 'a', 'U', 1.0, -Inf, 0.0)

    return ExtendedProblem(master_problem, artificial_global_pos_var,
            artificial_global_neg_var, Problem[],
            Dict{Problem, MasterConstr}(), Dict{Problem, MasterConstr}(),
            Problem[], params, vc_counter,
            PrimalSolution(), params.cut_up, params.cut_lo, 0,
            TimerOutputs.TimerOutput(), Dict{Int,Problem}())
end

get_problem(prob::ExtendedProblem,
            prob_ref::Int) = prob.problem_ref_to_problem[prob_ref]

function get_sp_convexity_bounds(prob::ExtendedProblem, prob_ref::Int)
    sp = get_problem(prob, prob_ref)
    sp_lb = prob.pricing_convexity_lbs[sp].cost_rhs
    sp_ub = prob.pricing_convexity_ubs[sp].cost_rhs
    return (sp_lb, sp_ub)
end

# Iterates through each problem in extended_problem,
# check its index and call function
# initialize_problem_optimizer(index, optimizer), using the dictionary
function initialize_problem_optimizer(extended_problem::ExtendedProblem,
         problemidx_optimizer_map::Dict{Int,MOI.AbstractOptimizer})

    if !haskey(problemidx_optimizer_map, extended_problem.master_problem.prob_ref)
        error("Optimizer was not set to master problem.")
    end
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

function set_prob_ref_to_problem_dict(extended_prob::ExtendedProblem)
    prob_ref_to_prob = extended_prob.problem_ref_to_problem
    master = extended_prob.master_problem
    subproblems = extended_prob.pricing_vect
    prob_ref_to_prob[master.prob_ref] = master
    for subprob in subproblems
        prob_ref_to_prob[subprob.prob_ref] = subprob
    end
end

function add_convexity_constraints(extended_problem::ExtendedProblem,
        pricing_prob::Problem, card_lb::Int, card_ub::Int)

    master_prob = extended_problem.master_problem
    convexity_lb_constr = ConvexityConstr(master_prob.counter,
            string("convexity_constr_lb_", pricing_prob.prob_ref),
            convert(Float, card_lb), 'G', 'M', 's')
    add_constraint(master_prob, convexity_lb_constr; update_moi = true)

    convexity_ub_constr = ConvexityConstr(master_prob.counter,
            string("convexity_constr_ub_", pricing_prob.prob_ref),
            convert(Float, card_ub), 'L', 'M', 's')
    add_constraint(master_prob, convexity_ub_constr; update_moi = true)

    extended_problem.pricing_convexity_lbs[pricing_prob] = convexity_lb_constr
    extended_problem.pricing_convexity_ubs[pricing_prob] = convexity_ub_constr
end

function add_artificial_variables(extended_prob::ExtendedProblem)
    add_variable(extended_prob.master_problem,
                 extended_prob.artificial_global_neg_var, true)
    add_variable(extended_prob.master_problem,
                 extended_prob.artificial_global_pos_var, true)
end

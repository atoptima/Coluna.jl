


###########################
##### CompactProblem ######
###########################


function initialize_problem_optimizer(problem::CompactProblem,
                                      optimizer::MOI.AbstractOptimizer)
    optimizer = MOIU.MOIU.CachingOptimizer(ModelForCachingOptimizer{Float64}(),
                                           optimizer)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),f)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    problem.optimizer = optimizer
end


###############################################################
########## Functions that interact directly with MOI ##########
###############################################################




function enforce_current_bounds_in_optimizer(
    optimizer::MOI.AbstractOptimizer, var::Variable)
    if (typeof(var.moi_def.type_index) == MoiVcType{MOI.ZeroOne}
        && var.moi_def.type_index.value != -1)
        MOI.delete(optimizer, var.moi_def.type_index)
        var.moi_def.type_index = MOI.add_constraint(
            optimizer, MOI.SingleVariable(var.moi_def.var_index), MOI.Integer())
    end
    if var.moi_def.bounds_index.value != -1
        moi_set = MOI.get(optimizer, MOI.ConstraintSet(), var.moi_def.bounds_index)
        MOI.set(optimizer, MOI.ConstraintSet(), var.moi_def.bounds_index,
                MOI.Interval(var.cur_lb, var.cur_ub))
    else
        var.moi_def.bounds_index = MOI.add_constraint(
            optimizer, MOI.SingleVariable(var.moi_def.var_index),
            MOI.Interval(var.cur_lb, var.cur_ub))
    end
end

function add_constr_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                 constr::Constraint)
    terms = compute_constr_moi_terms(constr)
    f = MOI.ScalarAffineFunction(terms, 0.0)
    constr.moi_index = MOI.add_constraint(
        optimizer, f, constr.set_type(constr.cur_cost_rhs)
    )
end

function update_constr_rhs_in_optimizer(optimizer::MOI.AbstractOptimizer,
                                        constr::Constraint)
    # This assumes the set_type is either GreaterThan or SmallerThan
    moi_set = MOI.get(optimizer, MOI.ConstraintSet(), constr.moi_index)
    moi_set_type = typeof(moi_set)
    @assert (moi_set_type isa MOI.GreaterThan || moi_set_type isa MOI.SmallerThan)
    MOI.set(optimizer, MOI.ConstraintSet(), constr.moi_index,
            moi_set_type(constr.cur_cost_rhs))
end

function compute_constr_moi_terms(constr::Constraint)
    return [
        MOI.ScalarAffineTerm{Float64}(var_val.second, var_val.first.moi_def.var_index)
        for var_val in constr.member_coef_map if var_val.first.status == Active
    ]
end

function update_moi_membership(optimizer::MOI.AbstractOptimizer, var::Variable,
                               constr::Constraint, coef::Float64)
    MOI.modify(optimizer, constr.moi_index,
               MOI.ScalarCoefficientChange{Float64}(var.moi_def.var_index, coef))
end

function update_moi_membership(optimizer::MOI.AbstractOptimizer,
                               col::MasterColumn)
    for constr_coef in col.member_coef_map
        update_moi_membership(optimizer, col, constr_coef[1], constr_coef[2])
    end
end

struct ProblemUpdate
    removed_cuts_from_problem::Vector{Constraint}
    added_cuts_to_problem::Vector{Constraint}
    removed_cols_from_problem::Vector{Variable}
    added_cols_to_problem::Vector{Variable}
    changed_bounds_or_cost::Vector{Variable}
    changed_rhs::Vector{Constraint}
end

function update_moi_optimizer(optimizer::MOI.AbstractOptimizer, is_relaxed::Bool,
                              prob_update::ProblemUpdate)
    # TODO implement caching through MOI.

    # Remove cuts
    for cut in prob_update.removed_cuts_from_problem
        remove_constr_from_optimizer(optimizer, cut)
    end
    # Remove variables
    for col in prob_update.removed_cols_from_problem
         remove_var_from_optimizer(optimizer, col)
    end

    # Add variables
    for col in prob_update.added_cols_to_problem
        add_variable_in_optimizer(optimizer, col, is_relaxed)
    end
    # Add cuts
    for cut in prob_update.added_cuts_to_problem
        add_constr_in_optimizer(optimizer, cut)
    end

    # Change bounds and/or cost
    for var in prob_update.changed_bounds_or_cost
        enforce_current_bounds_in_optimizer(optimizer, var)
        update_cost_in_optimizer(optimizer, var)
    end

    # Change rhs
    for constr in prob_update.changed_rhs
        update_constr_rhs_in_optimizer(optimizer, constr)
    end

end

###############################################################

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

load_problem_in_optimizer(problem::CompactProblem) = load_problem_in_optimizer(
    problem, problem.optimizer, problem.is_relaxed
)

function switch_primary_secondary_moi_def(problem::CompactProblem)
    for var in problem.var_manager.active_static_list
        switch_primary_secondary_moi_def(var)
    end
    for var in problem.var_manager.active_dynamic_list
        switch_primary_secondary_moi_def(var)
    end
    for constr in problem.constr_manager.active_static_list
        switch_primary_secondary_moi_indices(constr)
    end
    for constr in problem.constr_manager.active_dynamic_list
        switch_primary_secondary_moi_indices(constr)
    end
end

function call_moi_optimize_with_silence(optimizer::MOI.AbstractOptimizer)
    backup_stdout = stdout
    (rd_out, wr_out) = redirect_stdout()
    MOI.optimize!(optimizer)
    close(wr_out)
    close(rd_out)
    redirect_stdout(backup_stdout)
end

# Returns status, primal sol, and dual sol.
# Updates problem solutions by default
function optimize(problem::CompactProblem;
                  optimizer = problem.optimizer, update_problem = true)
    call_moi_optimize_with_silence(optimizer)
    status = MOI.get(optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)
    if MOI.get(optimizer, MOI.ResultCount()) >= 1
        primal_sol = retrieve_primal_sol(problem, optimizer)
        dual_sol = retrieve_dual_sol(problem, optimizer)
        if update_problem
            problem.primal_sol = primal_sol
            if dual_sol != nothing
                problem.dual_sol = dual_sol
            end
        end
        return (status, primal_sol, dual_sol)
    end
    @logmsg LogLevel(-4) string("Solver has no result to show.")
    return (status, nothing, nothing)
end


###########################
##### Reformulation #####
###########################

mutable struct Reformulation <: Problem
    master_problem::CompactProblem # restricted master in DW case.
    pricing_vect::Vector{Problem}
    art_var_manager::GlobalArtVarManager
    pricing_convexity_lbs::Dict{Problem, MasterConstr}
    pricing_convexity_ubs::Dict{Problem, MasterConstr}
    separation_vect::Vector{Problem}
    params::Params
    counter::VarConstrCounter
    solution::PrimalSolution
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    subtree_size_by_depth::Int
    timer_output::TimerOutputs.TimerOutput
    problem_ref_to_problem::Dict{Int,Problem}
    problem_ref_to_card_bounds::Dict{Int, Tuple{Int,Int}}
end

function Reformulation(prob_counter::ProblemCounter,
                         vc_counter::VarConstrCounter,
                         params::Params, primal_inc_bound::Float64,
                         dual_inc_bound::Float64)

    master_problem = SimpleCompactProblem(prob_counter, vc_counter)
    master_problem.is_relaxed = true

    return Reformulation(
        master_problem, Problem[], GlobalArtVarManager(),
        Dict{Problem, MasterConstr}(), Dict{Problem, MasterConstr}(),
        Problem[], params, vc_counter, PrimalSolution(), params.cut_up,
        params.cut_lo, 0, TimerOutputs.TimerOutput(), Dict{Int,Problem}(),
        Dict{Int, Tuple{Int,Int}}()
    )
end


function load_problem_in_optimizer(extended_problem::Reformulation)
    load_problem_in_optimizer(extended_problem.master_problem)
    for prob in extended_problem.pricing_vect
        load_problem_in_optimizer(prob)
    end
end


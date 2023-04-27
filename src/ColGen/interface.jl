"""
Structure where we store performance information about the column generation algorithm.
We can use these kpis as a stopping criteria for instance.
"""
abstract type AbstractColGenKpis end

struct UnboundedProblemError <: Exception
    message::String
end


"""
Placeholder method called before the column generation iteration.
Does nothing by default but can be redefined to print some informations for instance.
We strongly advise users against the use of this method to modify the context or the reformulation.
"""
@mustimplement "ColGen" before_colgen_iteration(ctx::AbstractColGenContext, phase) = nothing


"""
Runs an iteration of column generation.
"""
@mustimplement "ColGen" colgen_iteration(ctx::AbstractColGenContext, phase, reform) = nothing

"""
Placeholder method called after the column generation iteration.
Does nothing by default but can be redefined to print some informations for instance.
We strongly advise users against the use of this method to modify the context or the reformulation.
"""
@mustimplement "ColGen" after_colgen_iteration(::AbstractColGenContext, phase, stage, env, colgen_iteration, colgen_iter_output) = nothing

abstract type AbstractColGenPhaseOutput end

@mustimplement "ColGenPhase" colgen_phase_output_type(::AbstractColGenContext) = nothing

@mustimplement "ColGenPhase" get_best_ip_primal_master_sol_found(colgen_phase_output) = nothing

@mustimplement "ColGenPhase" get_final_lp_primal_master_sol_found(colgen_phase_output) = nothing

@mustimplement "ColGenPhase" get_final_db(colgen_phase_output) = nothing

abstract type AbstractColGenOutput end

@mustimplement "ColGen" colgen_output_type(::AbstractColGenContext) = nothing

@mustimplement "ColGen" new_output(::Type{<:AbstractColGenOutput}, colgen_phase_output::AbstractColGenPhaseOutput) = nothing

function run_colgen_phase!(context, phase, stage, env, ip_primal_sol)
    colgen_iteration = 1
    cutsep_iteration = 1
    colgen_iter_output = nothing
    while !stop_colgen_phase(context, phase, env, colgen_iter_output, colgen_iteration, cutsep_iteration)
        before_colgen_iteration(context, phase)
        colgen_iter_output = run_colgen_iteration!(context, phase, stage, env, ip_primal_sol)
        new_ip_primal_sol = get_master_ip_primal_sol(colgen_iter_output)
        if !isnothing(new_ip_primal_sol)
            ip_primal_sol = new_ip_primal_sol
        end
        after_colgen_iteration(context, phase, stage, env, colgen_iteration, colgen_iter_output)
        colgen_iteration += 1
    end
    O = colgen_phase_output_type(context)
    return new_phase_output(O, phase, stage, colgen_iter_output)
end

function run!(context, env, ip_primal_sol)
    phase_it = new_phase_iterator(context)
    phase = initial_phase(phase_it)
    stage_it = new_stage_iterator(context)
    stage = initial_stage(stage_it)
    phase_output = nothing
    while !isnothing(phase)
        setup_reformulation!(get_reform(context), phase)
        setup_context!(context, phase)
        phase_output = run_colgen_phase!(context, phase, stage, env, ip_primal_sol)
        ip_primal_sol = ColGen.get_master_ip_primal_sol(phase_output)
        phase = next_phase(phase_it, phase, phase_output)
        stage = next_stage(stage_it, stage, phase_output)
    end
    O = colgen_output_type(context)
    return new_output(O, phase_output)
end

############################################################################################
# Reformulation getters
############################################################################################
"Returns Dantzig-Wolfe reformulation."
@mustimplement "ColGen" get_reform(ctx) = nothing

"Returns master formulation."
@mustimplement "ColGen" get_master(ctx) = nothing

"Returns `true` if the objective sense is minimization; `false` otherwise."
@mustimplement "ColGen" is_minimization(ctx) = nothing

"""
    get_pricing_subprobs(ctx) -> Vector{Tuple{SuproblemId, SpFormulation}}

Returns subproblem formulations.
"""
@mustimplement "ColGen" get_pricing_subprobs(ctx) = nothing

############################################################################################
# Solution status getters
############################################################################################
"Returns true if a master or pricing problem result is infeasible; false otherwise."
@mustimplement "ColGen" is_infeasible(res) = nothing

"Returns true if a master or pricing problem result is unbounded; false otherwise."
@mustimplement "ColGen" is_unbounded(res) = nothing

"Returns true if a master or pricing problem result is optimal; false otherwise."
@mustimplement "ColGen" is_optimal(res) = nothing

############################################################################################
# Master resolution.
############################################################################################

"""
    optimize_master_lp_problem!(master, context, env) -> MasterResult

Returns an instance of a custom object `MasterResult` that implements following methods:
- `get_obj_val`: objective value of the master (mandatory)
- `get_primal_sol`: primal solution to the master (optional)
- `get_dual_sol`: dual solution to the master (mandatory otherwise column generation stops)

It should at least return a dual solution (obtained with LP optimization or subgradient) 
otherwise column generation cannot continue.
"""
@mustimplement "ColGenMaster" optimize_master_lp_problem!(master, context, env) = nothing

"""
Returns the optimal objective value of the master LP problem."
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenMaster" get_obj_val(master_res) = nothing

"""
Returns primal solution to the master LP problem. 
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenMaster" get_primal_sol(master_res) = nothing

"""
Returns dual solution to the master optimization problem. 
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenMaster" get_dual_sol(master_res) = nothing

"""
Updates dual value of the master constraints.
Dual values of the constraints can be used when the pricing solver supports non-robust cut.

**Note (by guimarqu)**: This is something that should be discussed because another option
is to provide the master LP dual solution to the pricing solver instead of storing the same
information at two different places.
"""
@mustimplement "ColGenMaster" update_master_constrs_dual_vals!(ctx, phase, reform, mast_lp_dual_sol) = nothing

"""
Returns a primal solution expressed in the original problem variables if the current master
LP solution is integer feasible; `nothing` otherwise.
"""
@mustimplement "ColGenMaster" check_primal_ip_feasibility!(mast_lp_primal_sol, ::AbstractColGenContext, phase, reform, env) = nothing

@mustimplement "ColGen" isbetter(new_ip_primal_sol, ip_primal_sol) = nothing

@mustimplement "ColGen" update_inc_primal_sol!(ctx::AbstractColGenContext, ip_primal_sol) = nothing

############################################################################################
# Reduced costs calculation.
############################################################################################
"""
Returns the original cost `c` of subproblems variables.
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts " get_subprob_var_orig_costs(ctx::AbstractColGenContext) = nothing

"""
Returns the coefficient matrix `A` of subproblem variables in the master
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts" get_subprob_var_coef_matrix(ctx::AbstractColGenContext) = nothing

"Updates reduced costs of variables of a given subproblem."
@mustimplement "ColGenReducedCosts" update_sp_vars_red_costs!(ctx::AbstractColGenContext, sp, red_costs) = nothing

############################################################################################
# Columns insertion.
############################################################################################

"""
Inserts columns into the master. Returns the number of columns inserted.
Implementation is responsible for checking if the column must be inserted and warn the user
if something unexpected happens.
"""
@mustimplement "ColGen" insert_columns!(reform, ctx, phase, columns) = nothing


function check_master_termination_status(mast_result)
    if !is_infeasible(mast_result) && !is_unbounded(mast_result)
        @assert !isnothing(get_dual_sol(mast_result))
    end
end

function check_pricing_termination_status(pricing_result)
    # TODO
end

@mustimplement "ColGen" compute_dual_bound(ctx, phase, master_lp_obj_val, master_dbs, mast_dual_sol) = nothing


abstract type AbstractColGenIterationOutput end

@mustimplement "ColGenIterationOutput" colgen_iteration_output_type(::AbstractColGenContext) = nothing

@mustimplement "ColGenIterationOutput" new_iteration_output(
    ::Type{<:AbstractColGenIterationOutput},
    min_sense,
    mlp,
    db,
    nb_new_cols,
    new_cut_in_master,
    infeasible_master,
    unbounded_master,
    infeasible_subproblem,
    unbounded_subproblem,
    time_limit_reached,
    master_primal_sol,
    ip_primal_sol,
    dual_sol
) = nothing

@mustimplement "ColGenIterationOutput" get_nb_new_cols(::AbstractColGenIterationOutput) = nothing

@mustimplement "ColGenIterationOutput" get_master_ip_primal_sol(::AbstractColGenIterationOutput) = nothing

@mustimplement "ColGenPhaseOutput" new_phase_output(::Type{<:AbstractColGenPhaseOutput}, phase, stage, ::AbstractColGenIterationOutput) = nothing

@mustimplement "ColGenPhaseOutput" get_master_ip_primal_sol(::AbstractColGenPhaseOutput) = nothing

_inf(is_min_sense) = is_min_sense ? Inf : -Inf

"""
    run_colgen_iteration!(context, phase, env) -> ColGenIterationOutput
"""
function run_colgen_iteration!(context, phase, stage, env, ip_primal_sol)
    master = get_master(context)
    is_min_sense = is_minimization(context)
    mast_result = optimize_master_lp_problem!(master, context, env)
    O = colgen_iteration_output_type(context)

    # Iteration continues only if master is not infeasible nor unbounded and has dual
    # solution.
    if is_infeasible(mast_result)
        return new_iteration_output(O, is_min_sense, nothing, _inf(is_min_sense), 0, false, true, false, false, false, false, nothing, nothing, nothing)
    elseif is_unbounded(mast_result)
        throw(UnboundedProblemError("Unbounded master problem."))
    end

    check_master_termination_status(mast_result)

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)
    if !isnothing(mast_primal_sol)
        # If the master LP problem has a primal solution, we can try to find a integer feasible
        # solution.
        # If the model has essential cut callbacks and the master LP solution is integral, one
        # needs to make sure that the master LP solution does not violate any essential cuts.
        # If an essential cut is violated, we expect that the `check_primal_ip_feasibility!` method
        # will add the violated cut to the master formulation.
        # If the formulation changes, one needs to restart the column generation to update
        # memoization to calculate reduced costs and stabilization.
        new_ip_primal_sol, new_cut_in_master = check_primal_ip_feasibility!(mast_primal_sol, context, phase, get_reform(context), env)
        if new_cut_in_master
            return new_iteration_output(O, is_min_sense, nothing, nothing, 0, true, false, false, false, false, false, nothing, nothing, nothing)
        end
        if !isnothing(new_ip_primal_sol) && isbetter(new_ip_primal_sol, ip_primal_sol)
            ip_primal_sol = new_ip_primal_sol
            update_inc_primal_sol!(context, ip_primal_sol) # TODO: change method name because the incumbent is maintained by colgen
        end
    end

    mast_dual_sol = get_dual_sol(mast_result)
    if isnothing(mast_dual_sol)
        error("Cannot continue")
        # error or stop? (depends on the context)
    end

    # TODO discussion.
    # Do we need this method?
    # I think we can just pass the master LP dual solution to the pricing solver. 
    update_master_constrs_dual_vals!(context, phase, get_reform(context), mast_dual_sol)

    # Stabilization
    # initialize stabilisation for the iteration
    # update_stab_after_rm_solve! 
    # stabcenter is master_dual_sol
    # return alpha * stab_center + (1 - alpha) * lp_dual_sol

    # With stabilization, you solve several times the suproblem because you can have misprice
    # loop:
    #   - solve all subproblems 
    #   - check if misprice 

    # Compute reduced cost (generic operation) by you must support math operations.
    c = get_subprob_var_orig_costs(context)
    A = get_subprob_var_coef_matrix(context)
    red_costs = c - transpose(A) * mast_dual_sol

    # Updates subproblems reduced costs.
    for (_, sp) in get_pricing_subprobs(context)
        update_sp_vars_red_costs!(context, sp, red_costs)
    end

    # To compute the master dual bound, we need a dual bound to each pricing subproblems.
    # So we ask for an initial dual bound for each pricing subproblem that we update when
    # solving the pricing subproblem.
    # Depending on the pricing strategy, the user can choose to solve only some subproblems.
    # If the some subproblems have not been solved, we use this initial dual bound to
    # compute the master dual bound.
    sps_db = Dict(sp_id => compute_sp_init_db(context, sp) for (sp_id, sp) in get_pricing_subprobs(context))

    # Solve pricing subproblems
    pricing_strategy = get_pricing_strategy(context, phase)
    sp_to_solve_it = pricing_strategy_iterate(pricing_strategy)

    # All generated columns will be stored in the following container. We will insert them
    # into the master after the optimization of the pricing subproblems.
    generated_columns = set_of_columns(context)

    while !isnothing(sp_to_solve_it)
        (sp_id, sp_to_solve), state = sp_to_solve_it
        optimizer = get_pricing_subprob_optimizer(stage, sp_to_solve)
        pricing_result = optimize_pricing_problem!(context, sp_to_solve, env, optimizer, mast_dual_sol)

        # Iteration continues only if the pricing solution is not infeasible nor unbounded.
        if is_infeasible(pricing_result)
            # TODO: if the lower multiplicity of the subproblem is zero, we can continue.
            return new_iteration_output(O, is_min_sense, nothing, _inf(is_min_sense), 0, false, false, false, true, false, false, mast_primal_sol, ip_primal_sol, mast_dual_sol)
        elseif is_unbounded(pricing_result)
            # We do not support unbounded pricing (even if it's theorically possible).
            # We must stop Coluna here by throwing an exception because we can't claim
            # the problem is unbounded.
            throw(UnboundedProblemError("Unbounded subproblem."))
        end

        check_pricing_termination_status(pricing_result)

        primal_sols = get_primal_sols(pricing_result)
        nb_cols_pushed = 0
        for primal_sol in primal_sols # multi column generation support.
            # The implementation  is reponsible for checking if the column is a candidate
            # for insertion into the master.
            if push_in_set!(context, generated_columns, primal_sol)
                nb_cols_pushed += 1
            end
        end

        # Updates the initial bound if the pricing subproblem result has a dual bound.
        sp_db = get_dual_bound(pricing_result)
        if !isnothing(sp_db)
            sps_db[sp_id] = sp_db
        end

        sp_to_solve_it = pricing_strategy_iterate(pricing_strategy, state)
    end

    # Insert columns into the master.
    # The implementation is responsible for checking if the column is "valid".
    col_ids = insert_columns!(get_reform(context), context, phase, generated_columns)
    nb_cols_inserted = length(col_ids)

    master_lp_obj_val = get_obj_val(mast_result)

    # compute valid dual bound using the dual bounds returned by the user (cf pricing result).
    valid_db = compute_dual_bound(context, phase, master_lp_obj_val, sps_db, mast_dual_sol)

    pseudo_db = 0 # same but using primal bound of the pricing result.
    # pseudo_db used only in the stabilization (update_stability_center!)

    # update_stab_after_gencols!

    return new_iteration_output(O, is_min_sense, master_lp_obj_val, valid_db, nb_cols_inserted, false, false, false, false, false, false, mast_primal_sol, ip_primal_sol, mast_dual_sol)
end


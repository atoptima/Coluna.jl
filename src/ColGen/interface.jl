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
@mustimplement "ColGen" after_colgen_iteration(::AbstractColGenContext, phase, stage, env, colgen_iteration, stab, colgen_iter_output) = nothing

abstract type AbstractColGenPhaseOutput end

@mustimplement "ColGenPhase" colgen_phase_output_type(::AbstractColGenContext) = nothing

@mustimplement "ColGenPhase" get_best_ip_primal_master_sol_found(colgen_phase_output) = nothing

@mustimplement "ColGenPhase" get_final_lp_primal_master_sol_found(colgen_phase_output) = nothing

@mustimplement "ColGenPhase" get_final_db(colgen_phase_output) = nothing

abstract type AbstractColGenOutput end

@mustimplement "ColGen" colgen_output_type(::AbstractColGenContext) = nothing

@mustimplement "ColGen" new_output(::Type{<:AbstractColGenOutput}, colgen_phase_output::AbstractColGenPhaseOutput) = nothing

@mustimplement "ColGen" stop_colgen(context, phase_output) = nothing

function run_colgen_phase!(context, phase, stage, env, ip_primal_sol, stab; iter = 1)
    iteration = iter
    colgen_iter_output = nothing
    while !stop_colgen_phase(context, phase, env, colgen_iter_output, iteration)
        before_colgen_iteration(context, phase)
        colgen_iter_output = run_colgen_iteration!(context, phase, stage, env, ip_primal_sol, stab)
        new_ip_primal_sol = get_master_ip_primal_sol(colgen_iter_output)
        if !isnothing(new_ip_primal_sol)
            ip_primal_sol = new_ip_primal_sol
        end
        after_colgen_iteration(context, phase, stage, env, iteration, stab, colgen_iter_output)
        iteration += 1
    end
    O = colgen_phase_output_type(context)
    return new_phase_output(O, is_minimization(context), phase, stage, colgen_iter_output, iteration)
end

function run!(context, env, ip_primal_sol; iter = 1)
    phase_it = new_phase_iterator(context)
    phase = initial_phase(phase_it)
    stage_it = new_stage_iterator(context)
    stage = initial_stage(stage_it)
    stab = setup_stabilization!(context, get_master(context))
    phase_output = nothing
    while !isnothing(phase) && !stop_colgen(context, phase_output) && !isnothing(stage)
        setup_reformulation!(get_reform(context), phase)
        setup_context!(context, phase)
        last_iter = isnothing(phase_output) ? iter : phase_output.nb_iterations
        phase_output = run_colgen_phase!(context, phase, stage, env, ip_primal_sol, stab; iter = last_iter)
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

Returns an instance of a custom object `MasterResult` that implements the following methods:
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
Returns a primal solution expressed in the original problem variables if the current master
LP solution is integer feasible; `nothing` otherwise.
"""
@mustimplement "ColGenMaster" check_primal_ip_feasibility!(mast_lp_primal_sol, ::AbstractColGenContext, phase, reform, env) = nothing

"""
Returns `true` if the new master IP primal solution is better than the current; `false` otherwise.
"""
@mustimplement "ColGenMaster" isbetter(new_ip_primal_sol, ip_primal_sol) = nothing

"""
Updates the current master IP primal solution.
"""
@mustimplement "ColGenMaster" update_inc_primal_sol!(ctx::AbstractColGenContext, ip_primal_sol) = nothing

############################################################################################
# Reduced costs calculation.
############################################################################################
"""
Updates dual value of the master constraints.
Dual values of the constraints can be used when the pricing solver supports non-robust cuts.
"""
@mustimplement "ColGenReducedCosts" update_master_constrs_dual_vals!(ctx, mast_lp_dual_sol) = nothing

"""
Updates reduced costs of the master variables.
"""
@mustimplement "ColGenReducedCosts" update_reduced_costs!(context, phase, red_costs) = nothing

"""
Returns the original cost `c` of subproblems variables.
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts" get_subprob_var_orig_costs(ctx::AbstractColGenContext) = nothing

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


"""
    compute_dual_bound(ctx, phase, master_lp_obj_val, master_dbs, mast_dual_sol) -> Float64

Caculates the dual bound at a given iteration of column generation.
The dual bound is composed of:
- `master_lp_obj_val`: objective value of the master LP problem
- `master_dbs`: dual values of the pricing subproblems
- the contribution of the master convexity constraints that you should compute from `mast_dual_sol`.
"""
@mustimplement "ColGen" compute_dual_bound(ctx, phase, master_dbs, mast_dual_sol) = nothing

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

@mustimplement "ColGenPhaseOutput" new_phase_output(::Type{<:AbstractColGenPhaseOutput}, min_sense, phase, stage, ::AbstractColGenIterationOutput, iteration) = nothing

@mustimplement "ColGenPhaseOutput" get_master_ip_primal_sol(::AbstractColGenPhaseOutput) = nothing

_inf(is_min_sense) = is_min_sense ? Inf : -Inf

"""
    run_colgen_iteration!(context, phase, env) -> ColGenIterationOutput
"""
function run_colgen_iteration!(context, phase, stage, env, ip_primal_sol, stab)
    master = get_master(context)
    is_min_sense = is_minimization(context)
    O = colgen_iteration_output_type(context)

    mast_result = optimize_master_lp_problem!(master, context, env)

    # Iteration continues only if master is not infeasible nor unbounded and has dual
    # solution.
    if is_infeasible(mast_result)
        return new_iteration_output(O, is_min_sense, nothing, _inf(is_min_sense), 0, false, true, false, false, false, false, nothing, nothing, nothing)
    elseif is_unbounded(mast_result)
        throw(UnboundedProblemError("Unbounded master problem."))
    end

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)
    if !isnothing(mast_primal_sol)  && isbetter(mast_primal_sol, ip_primal_sol)
        # If the master LP problem has a primal solution, we can try to find a integer feasible
        # solution.
        # If the model has essential cut callbacks and the master LP solution is integral, one
        # needs to make sure that the master LP solution does not violate any essential cuts.
        # If an essential cut is violated, we expect that the `check_primal_ip_feasibility!` method
        # will add the violated cut to the master formulation.
        # If the formulation changes, one needs to restart the column generation to update
        # memoization to calculate reduced costs and stabilization.
        # TODO: the user can get the reformulation from the context.
        new_ip_primal_sol, new_cut_in_master = check_primal_ip_feasibility!(mast_primal_sol, context, phase, get_reform(context), env)
        if new_cut_in_master
            return new_iteration_output(O, is_min_sense, nothing, nothing, 0, true, false, false, false, false, false, nothing, nothing, nothing)
        end
        if !isnothing(new_ip_primal_sol)
            ip_primal_sol = new_ip_primal_sol
            update_inc_primal_sol!(context, ip_primal_sol)
        end
    end

    mast_dual_sol = get_dual_sol(mast_result)
    if isnothing(mast_dual_sol)
        error("Cannot continue")
        # TODO: user friendly error message.
    end

    # Stores dual solution in the constraint. This is used when the pricing solver supports
    # non-robust cuts.
    update_master_constrs_dual_vals!(context, mast_dual_sol)

    # Compute reduced cost (generic operation) by you must support math operations.
    # We always compute the reduced costs of the subproblem variables against the real master
    # dual solution because this is the cost of the subproblem variables in the pricing problems
    # if we don't use stabilization, or because we use this cost to compute the real reduced cost
    # of the columns when using stabilization.
    c = get_subprob_var_orig_costs(context)
    A = get_subprob_var_coef_matrix(context)
    red_costs = c - transpose(A) * mast_dual_sol

    # Buffer when using stabilization to compute the real reduced cost
    # of the column once generated.
    update_reduced_costs!(context, phase, red_costs)
    
    # Stabilization
    stab_changes_mast_dual_sol = update_stabilization_after_master_optim!(stab, phase, mast_dual_sol)
    cur_mast_dual_sol = get_master_dual_sol(stab, phase, mast_dual_sol) 

    # TODO: check the compatibility of the pricing strategy and the stabilization.

    # All generated columns during this iteration will be stored in the following container. 
    # We will insert them into the master after the optimization of the pricing subproblems.
    # It is empty.
    generated_columns = set_of_columns(context)

    valid_db = nothing

    misprice = true # because we need to run the pricing at least once.
    # This variable is updated at the end of the pricing loop.
    # If there is no stabilization, the pricing loop is run only once.

    while misprice
        # We will optimize the pricing subproblem using the master dual solution returned
        # by the stabilization. We this need to recompute the reduced cost of the subproblem
        # variables if the stabilization changes the master dual solution.
        cur_red_costs = if stab_changes_mast_dual_sol
            c - transpose(A) * cur_mast_dual_sol
        else
            red_costs
        end

        # Updates subproblems reduced costs.
        for (_, sp) in get_pricing_subprobs(context)
            update_sp_vars_red_costs!(context, sp, cur_red_costs)
        end

        # To compute the master dual bound, we need a dual bound to each pricing subproblems.
        # So we ask for an initial dual bound for each pricing subproblem that we update when
        # solving the pricing subproblem.
        # Depending on the pricing strategy, the user can choose to solve only some subproblems.
        # If the some subproblems have not been solved, we use this initial dual bound to
        # compute the master dual bound.
        sps_db = Dict(sp_id => compute_sp_init_db(context, sp) for (sp_id, sp) in get_pricing_subprobs(context))

        # The primal bound is used to compute the psueudo dual bound (used by stabilization).
        sps_pb = Dict(sp_id => compute_sp_init_pb(context, sp) for (sp_id, sp) in get_pricing_subprobs(context))

        # Solve pricing subproblems
        pricing_strategy = get_pricing_strategy(context, phase)
        sp_to_solve_it = pricing_strategy_iterate(pricing_strategy)
        
        while !isnothing(sp_to_solve_it)
            (sp_id, sp_to_solve), state = sp_to_solve_it
            optimizer = get_pricing_subprob_optimizer(stage, sp_to_solve)
            pricing_result = optimize_pricing_problem!(context, sp_to_solve, env, optimizer, mast_dual_sol, stab_changes_mast_dual_sol)

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

            sp_pb = get_primal_bound(pricing_result)
            if !isnothing(sp_pb)
                sps_pb[sp_id] = sp_pb
            end

            sp_to_solve_it = pricing_strategy_iterate(pricing_strategy, state)
        end

        # compute valid dual bound using the dual bounds returned by the user (cf pricing result).
        valid_db = compute_dual_bound(context, phase, sps_db, cur_mast_dual_sol)
    
        # pseudo dual bound is used for stabilization only.
        pseudo_db = compute_dual_bound(context, phase, sps_pb, cur_mast_dual_sol)

        update_stabilization_after_pricing_optim!(stab, context, generated_columns, master, valid_db, pseudo_db, mast_dual_sol)

        # We have finished to solve all pricing subproblems.
        # If we have stabilization, we need to check if we have misprice.
        # If we have misprice, we need to update the stabilization center and solve again
        # the pricing subproblems.
        # If we don't have misprice, we can stop the pricing loop.
        misprice = check_misprice(stab, generated_columns, mast_dual_sol)
        if misprice
            update_stabilization_after_misprice!(stab, mast_dual_sol)
            cur_mast_dual_sol = get_master_dual_sol(stab, phase, mast_dual_sol)
        end
    end

    # Insert columns into the master.
    # The implementation is responsible for checking if the column is "valid".
    col_ids = insert_columns!(context, phase, generated_columns)
    nb_cols_inserted = length(col_ids)

    update_stabilization_after_iter!(stab, mast_dual_sol)

    return new_iteration_output(O, is_min_sense, get_obj_val(mast_result), valid_db, nb_cols_inserted, false, false, false, false, false, false, mast_primal_sol, ip_primal_sol, mast_dual_sol)
end
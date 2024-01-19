"API and high-level implementation of the column generation algorithm in Julia."
module ColGen

include("../MustImplement/MustImplement.jl")
using .MustImplement

"""
Supertype for the objects to which belongs the implementation of the column generation and 
that stores any kind of information during the execution of the column generation algorithm.

**IMPORTANT**: implementation of the column generation mainly depends on the context type.
"""
abstract type AbstractColGenContext end 

include("stages.jl")
include("phases.jl")
include("pricing.jl")
include("stabilization.jl")
include("interface.jl")

"""
    run!(ctx, env, ip_primal_sol; iter = 1) -> AbstractColGenOutput

Runs the column generation algorithm.

Arguments are:
- `ctx`: column generation context
- `env`: Coluna environment
- `ip_primal_sol`: current best primal solution to the master problem
- `iter`: iteration number (default: 1)

This function is responsible for initializing the column generation context, the reformulation,
and the stabilization. We iterate on the loop each time the phase or the stage changes.
"""
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
        phase = next_phase(phase_it, phase, phase_output)
        stage = next_stage(stage_it, stage, phase_output)
    end
    O = colgen_output_type(context)
    return new_output(O, phase_output)
end

"""
    run_colgen_phase!(ctx, phase, stage, env, ip_primal_sol, stab; iter = 1) -> AbstractColGenPhaseOutput

Runs a phase of the column generation algorithm.

Arguments are:
- `ctx`: column generation context
- `phase`: current column generation phase
- `stage`: current column generation stage
- `env`: Coluna environment
- `ip_primal_sol`: current best primal solution to the master problem
- `stab`: stabilization
- `iter`: iteration number (default: 1)

This function is responsible for running the column generation iterations until the phase
is finished.
"""
function run_colgen_phase!(context, phase, stage, env, ip_primal_sol, stab; iter = 1)
    iteration = iter
    colgen_iter_output = nothing
    incumbent_dual_bound = nothing
    while !stop_colgen_phase(context, phase, env, colgen_iter_output, incumbent_dual_bound, ip_primal_sol, iteration)
        before_colgen_iteration(context, phase)
        colgen_iter_output = run_colgen_iteration!(context, phase, stage, env, ip_primal_sol, stab)
        dual_bound = ColGen.get_dual_bound(colgen_iter_output)
        if !isnothing(dual_bound) && (isnothing(incumbent_dual_bound) || is_better_dual_bound(context, dual_bound, incumbent_dual_bound))
            incumbent_dual_bound = dual_bound
        end
        after_colgen_iteration(context, phase, stage, env, iteration, stab, ip_primal_sol, colgen_iter_output)
        iteration += 1
    end
    O = colgen_phase_output_type(context)
    return new_phase_output(O, is_minimization(context), phase, stage, colgen_iter_output, iteration, incumbent_dual_bound)
end

"""
    run_colgen_iteration!(context, phase, stage, env, ip_primal_sol, stab) -> AbstractColGenIterationOutput

Runs an iteration of column generation.

Arguments are:
- `context`: column generation context
- `phase`: current column generation phase
- `stage`: current column generation stage
- `env`: Coluna environment
- `ip_primal_sol`: current best primal solution to the master problem
- `stab`: stabilization
"""
function run_colgen_iteration!(context, phase, stage, env, ip_primal_sol, stab)
    master = get_master(context)
    is_min_sense = is_minimization(context)
    O = colgen_iteration_output_type(context)

    mast_result = optimize_master_lp_problem!(master, context, env)

    # Iteration continues only if master is not infeasible nor unbounded and has dual
    # solution.
    if is_infeasible(mast_result)
        return new_iteration_output(O, is_min_sense, nothing, _inf(is_min_sense), 0, false, true, false, false, false, false, nothing, ip_primal_sol, nothing)
    elseif is_unbounded(mast_result)
        throw(UnboundedProblemError("Unbounded master problem."))
    end

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)
    if !isnothing(mast_primal_sol) && is_better_primal_sol(mast_primal_sol, ip_primal_sol)
        # If the master LP problem has a primal solution, we can try to find a integer feasible
        # solution.
        # If the model has essential cut callbacks and the master LP solution is integral, one
        # needs to make sure that the master LP solution does not violate any essential cuts.
        # If an essential cut is violated, we expect that the `check_primal_ip_feasibility!` method
        # will add the violated cut to the master formulation.
        # If the formulation changes, one needs to restart the column generation to update
        # memoization to calculate reduced costs and stabilization.
        # TODO: the user can get the reformulation from the context.
        new_ip_primal_sol, new_cut_in_master = check_primal_ip_feasibility!(mast_primal_sol, context, phase, env)
        if new_cut_in_master
            return new_iteration_output(O, is_min_sense, nothing, nothing, 0, true, false, false, false, false, false, nothing, ip_primal_sol, nothing)
        end
        if !isnothing(new_ip_primal_sol)
            update_inc_primal_sol!(context, ip_primal_sol, new_ip_primal_sol)
        end
    end

    mast_dual_sol = get_dual_sol(mast_result)
    if isnothing(mast_dual_sol)
        error("Column generation interrupted: LP solver did not return an optimal dual solution")
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
        # `sep_mast_dual_sol` is the master dual solution used to optimize the pricing subproblems.
        # in the current misprice iteration.
        sep_mast_dual_sol = get_stab_dual_sol(stab, phase, mast_dual_sol)

        # We will optimize the pricing subproblem using the master dual solution returned
        # by the stabilization. We this need to recompute the reduced cost of the subproblem
        # variables if the stabilization changes the master dual solution.
        cur_red_costs = if stab_changes_mast_dual_sol
            c - transpose(A) * sep_mast_dual_sol
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
        valid_db = compute_dual_bound(context, phase, sps_db, generated_columns, sep_mast_dual_sol)
    
        # pseudo dual bound is used for stabilization only.
        pseudo_db = compute_dual_bound(context, phase, sps_pb, generated_columns, sep_mast_dual_sol)

        update_stabilization_after_pricing_optim!(stab, context, generated_columns, master, pseudo_db, sep_mast_dual_sol)

        # We have finished to solve all pricing subproblems.
        # If we have stabilization, we need to check if we have misprice, i.e. if smoothing is active 
        # and no negative reduced cost columns are generated
        # If we have misprice, we need to update the stabilization center and the smoothed dual solution 
        # and solve again the pricing subproblems.
        # If we don't have misprice, we can stop the pricing loop.
        misprice = check_misprice(stab, generated_columns, mast_dual_sol)
        if misprice
            update_stabilization_after_misprice!(stab, mast_dual_sol)
        end
    end

    # Insert columns into the master.
    # The implementation is responsible for checking if the column is "valid".
    col_ids = insert_columns!(context, phase, generated_columns)
    nb_cols_inserted = length(col_ids)

    update_stabilization_after_iter!(stab, mast_dual_sol)

    return new_iteration_output(O, is_min_sense, get_obj_val(mast_result), valid_db, nb_cols_inserted, false, false, false, false, false, false, mast_primal_sol, ip_primal_sol, mast_dual_sol)
end

end
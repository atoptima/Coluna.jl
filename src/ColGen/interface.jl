"""
Structure where we store performance information about the column generation algorithm.
We can use these kpis as a stopping criteria for instance.
"""
abstract type AbstractColGenKpis end


"""
Placeholder method called before the column generation iteration.
Does nothing by default but can be redefined to print some informations for instance.
We strongly advise users against the use of this method to modify the context or the reformulation.
"""
@mustimplement "ColGen" before_colgen_iteration(ctx::AbstractColGenContext, phase, reform)


"""
Runs an iteration of column generation.
"""
@mustimplement "ColGen" colgen_iteration(ctx::AbstractColGenContext, phase, reform)

"""
Placeholder method called after the column generation iteration.
Does nothing by default but can be redefined to print some informations for instance.
We strongly advise users against the use of this method to modify the context or the reformulation.
"""
@mustimplement "ColGen" after_colgen_iteration(::AbstractColGenContext, phase, reform, colgen_iter_output)

@mustimplement "ColGen" initial_primal_solution()

@mustimplement "ColGen" initial_dual_solution()

@mustimplement "ColGen" before_cut_separation()

@mustimplement "ColGen" run_cut_separation!()

@mustimplement "ColGen" after_cut_separation()

function run_colgen_phase!(context, phase, reform)
    colgen_iteration = 0
    cutsep_iteration = 0
    while !stop_colgen_phase(context, phase, reform)
        # cleanup ?
        before_colgen_iteration(context, phase, reform)
        colgen_iter_output = run_colgen_iteration!(context, phase, reform)
        after_colgen_iteration(context, phase, reform, colgen_iter_output)
        colgen_iteration += 1
        if separate_cuts()
            before_cut_separation()
            run_cut_separation!(context, phase, reform)
            after_cut_separation()
            cutsep_iteration += 1
        end
    end
end

function run!()
    phase = initial_phase(context)
    while !isnothing(phase)
        setup_reformulation(reform, phase, context)
        run_colgen_phase!(context, phase, reform)
        phase = next_phase(context, phase, reform)
    end
    return
end

############################################################################################
# Reformulation getters
############################################################################################
"Returns Dantzig-Wolfe reformulation."
@mustimplement "ColGen" get_reform(ctx)

"Returns master formulation."
@mustimplement "ColGen" get_master(ctx)

"""
    get_pricing_subprobs(ctx) -> Vector{Tuple{SuproblemId, SpFormulation}}

Returns subproblem formulations.
"""
@mustimplement "ColGen" get_pricing_subprobs(ctx)

############################################################################################
# Solution status getters
############################################################################################
"Returns true if a master or pricing problem result is infeasible; false otherwise."
@mustimplement "ColGen" is_infeasible(res)

"Returns true if a master or pricing problem result is unbounded; false otherwise."
@mustimplement "ColGen" is_unbounded(res)

"Returns true if a master or pricing problem result is optimal; false otherwise."
@mustimplement "ColGen" is_optimal(res)

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
@mustimplement "ColGenMaster" optimize_master_lp_problem!(master, context, env)

"""
Returns the optimal objective value of the master LP problem."
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenMaster" get_obj_val(master_res)

"""
Returns primal solution to the master LP problem. 
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenMaster" get_primal_sol(master_res)

"""
Returns dual solution to the master optimization problem. 
See `optimize_master_lp_problem!`.
"""
@mustimplement "ColGenMaster" get_dual_sol(master_res)

"""
Updates dual value of the master constraints.
Dual values of the constraints can be used when the pricing solver supports non-robust cut.

**Note (by guimarqu)**: This is something that should be discussed because another option
is to provide the master LP dual solution to the pricing solver instead of storing the same
information at two different places.
"""
@mustimplement "ColGenMaster" update_master_constrs_dual_vals!(ctx, phase, reform, mast_lp_dual_sol)

"""
Returns a primal solution expressed in the original problem variables if the current master
LP solution is integer feasible; `nothing` otherwise.
"""
@mustimplement "ColGenMaster" check_primal_ip_feasibility(mast_lp_primal_sol, phase, reform)

############################################################################################
# Reduced costs calculation.
############################################################################################
"""
Returns the original cost `c` of subproblems variables.
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts " get_subprob_var_orig_costs(ctx::AbstractColGenContext)

"""
Returns the coefficient matrix `A` of subproblem variables in the master
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts" get_subprob_var_coef_matrix(ctx::AbstractColGenContext)

"Updates reduced costs of variables of a given subproblem."
@mustimplement "ColGenReducedCosts" update_sp_vars_red_costs!(ctx::AbstractColGenContext, sp, red_costs)

############################################################################################
# Columns insertion.
############################################################################################

"""
Inserts columns into the master. Returns the number of columns inserted.
Implementation is responsible for checking if the column must be inserted and warn the user
if something unexpected happens.
"""
@mustimplement "ColGen" insert_columns!(reform, ctx, phase, columns)


function check_master_termination_status(mast_result)
    if !is_infeasible(mast_result) && !is_unbounded(mast_result)
        @assert !isnothing(get_dual_sol(mast_result))
    end
end

function check_pricing_termination_status(pricing_result)
    # TODO
end

function compute_dual_bound(ctx, phase, master_lp_obj_val, master_dbs)
    # TODO pure master variables are missing.
    @show master_lp_obj_val
    @show master_dbs
    return master_lp_obj_val + mapreduce(((id, val),) -> val, +, master_dbs)
end

struct ColGenIterationOutput
    mlp::Union{Nothing, Float64}
    db::Union{Nothing, Float64}
    nb_new_cols::Int
    infeasible_master::Bool
    unbounded_master::Bool
    infeasible_subproblem::Bool
    unbounded_subproblem::Bool
end

"""
    run_colgen_iteration!(context, phase, reform) -> ColGenIterationOutput
"""
function run_colgen_iteration!(context, phase, env)
    master = get_master(context)
    mast_result = optimize_master_lp_problem!(master, context, env)

    # Iteration continues only if master is not infeasible nor unbounded and has dual
    # solution.
    if is_infeasible(mast_result)
        return ColGenIterationOutput(nothing, Inf, 0, true, false, false, false)
    elseif is_unbounded(mast_result)
        return ColGenIterationOutput(-Inf, nothing, 0, false, true, false, false)
    end

    check_master_termination_status(mast_result)

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)
    if !isnothing(mast_primal_sol)
        # If the master LP problem has a primal solution, we can try to find a integer feasible
        # solution.
        ip_primal_sol = check_primal_ip_feasibility(phase, mast_primal_sol, get_reform(context))
        if !isnothing(ip_primal_sol)
            update_inc_primal_sol!(context, ip_primal_sol)
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
        pricing_result = optimize_pricing_problem!(context, sp_to_solve, env, mast_dual_sol)

        # Iteration continues only if the pricing solution is not infeasible nor unbounded.
        if is_infeasible(pricing_result)
            return ColGenIterationOutput(nothing, Inf, 0, false, false, true, false)
        elseif is_unbounded(pricing_result)
            return ColGenIterationOutput(nothing, nothing, 0, false, false, false, true)
        end

        check_pricing_termination_status(pricing_result)

        primal_sols = get_primal_sols(pricing_result)
        for primal_sol in primal_sols # multi column generation support.
            # The implementation  is reponsible for checking if the column is a candidate
            # for insertion into the master.
            push_in_set!(generated_columns, primal_sol)
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
    nb_cols_inserted = insert_columns!(get_reform(context), context, phase, generated_columns)

    master_lp_obj_val = get_obj_val(mast_result)

    # compute valid dual bound using the dual bounds returned by the user (cf pricing result).
    valid_db = compute_dual_bound(context, phase, master_lp_obj_val, sps_db)

    pseudo_db = 0 # same but using primal bound of the pricing result.
    # pseudo_db used only in the stabilization (update_stability_center!)

    # update_stab_after_gencols!

    # check gap

    return ColGenIterationOutput(master_lp_obj_val, valid_db, nb_cols_inserted, false, false, false, false)
end


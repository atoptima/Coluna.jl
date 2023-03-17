abstract type AbstractColGenContext end 

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
# Master resolution.
############################################################################################

"""
Returns an instance of an object that implements both following functions:
- `get_primal_sol`: primal solution to the master (optional)
- `get_dual_sol`: dual solution to the master (mandatory otherwise column generation stops)

It should at least return a dual solution (obtained with LP optimization or subgradient) 
otherwise column generation cannot continue.
"""
@mustimplement "ColGenIteration" optimize_master_lp_problem!(master, context, env)

"""
Returns primal solution of master optimization problem. 
See `optimize_master_problem!`.
"""
@mustimplement "ColGenIteration" get_primal_sol()

"""
Returns dual solution of master optimization problem. 
See `optimize_master_problem!`.
"""
@mustimplement "ColGenIteration" get_dual_sol()

############################################################################################
# Reduced costs calculation.
############################################################################################
"""
Returns the original cost `c` of subproblems variables.
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts " get_orig_costs(ctx::AbstractColGenContext)

"""
Returns the coefficient matrix `A` of subproblem variables in the master
to compute reduced cost `̄c = c - transpose(A) * π`.
"""
@mustimplement "ColGenReducedCosts" get_coef_matrix(ctx::AbstractColGenContext)

"Update reduced costs of variables of a given subproblem."
@mustimplement "ColGenReducedCosts" update_sp_vars_red_costs!(ctx::AbstractColGenContext, sp, red_costs)


############################################################################################







"TODO"
@mustimplement "ColGenIteration" update_master_constrs_dual_vals!()



"Returns the dual bound to the master."
@mustimplement "ColGenIteration" compute_dual_bound!()

"Inserts columns into the master. Returns the number of columns inserted."
@mustimplement "ColGenIteration" insert_columns!()



@mustimplement "ColGenIteration" check_primal_ip_feasibility()

@mustimplement "ColGenIteration" get_master(ctx)

@mustimplement "ColGenIteration" get_reform(ctx)



@mustimplement "ColGenIteration" get_pricing_subprobs(context)


function check_master_termination_status(mast_result)
    # TODO
end

function check_pricing_termination_status(pricing_result)
    # TODO
end

function compute_dual_bound(ctx, phase, master_lp, master_dbs)
    return master_lp - mapreduce(((id, val),) -> val, +, master_dbs)
end

"""
    run_colgen_iteration!(context, phase, reform)
"""
function run_colgen_iteration!(context, phase, env)
    master = get_master(context)
    mast_result = optimize_master_lp_problem!(master, context, env)

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
        # error or stop? (depends on the context)
    end

    update_master_constrs_dual_vals!(context, phase, get_reform(context), mast_dual_sol)

    # Stabilization

    # Compute reduced cost (generic operation) by you must support math operations.
    c = get_orig_costs(context)
    A = get_coef_matrix(context)
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
    generated_columns = pool_of_columns(context)

    while !isnothing(sp_to_solve_it)
        (sp_id, sp_to_solve), state = sp_to_solve_it
        pricing_result = optimize_pricing_problem!(context, sp_to_solve)
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

        sp_to_solve_it = iterate(sp_to_solve_it, state)
    end

    # Insert columns into the master.
    # The implementation is responsible for checking if the column is "valid".
    insert_columns!(context, phase, get_reform(context), generated_columns)


    db = compute_dual_bound!(context, phase, master_lp, sps_db)
    # check gap

    return
end


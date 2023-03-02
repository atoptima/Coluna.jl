abstract type AbstractColGenContext end 

"""
Structure where we store performance information about the column generation algorithm.
We can use these kpis as a stopping criteria for instance.
"""
abstract type AbstractColGendKpis end

"""
A phase of the column generation.
Each phase is associated with a specific set up of the reformulation.
"""
abstract type AbstractColGenPhase end

"Returns the phase with which the column generation algorithm must start." 
@mustimplement "ColGen" initial_phase(::AbstractColGenContext)

"""
Returns the next phase of the column generation algorithm.
Returns `nothing` if the algorithm must stop.
"""
@mustimplement "ColGen" next_phase(::AbstractColGenContext, phase::AbstractColGenPhase, reform)

"Setup the reformulation for the given phase."
@mustimplement "ColGen" setup_reformulation(::AbstractColGenContext, ::AbstractColGenPhase, reform)

"Returns `true` if the column generation phase must stop."
@mustimplement "ColGen" stop_colgen_phase(context, phase, reform)

@mustimplement "ColGen" before_colgen_iteration(::AbstractColGenContext)

@mustimplement "ColGen" colgen_iteration(::AbstractColGenContext)

@mustimplement "ColGen" after_colgen_iteration(::AbstractColGenContext)

@mustimplement "ColGen" initial_primal_solution()

@mustimplement "ColGen" initial_dual_solution()

function run_colgen_phase!(context, phase, reform)
    while !stop_colgen_phase(context, phase, reform)
        # cleanup ?
        before_colgen_iteration(context)
        run_colgen_iteration!(context, phase, reform)
        after_colgen_iteration(context)
    end
end

function run!()
    phase = initial_phase(context)
    while !isnothing(phase)
        setup_reformulation(context, phase, reform)
        run_colgen_phase!(context, phase, reform)
        phase = next_phase(context, phase, reform)
    end
    return
end

############################################################################################
# Iteration of a column generation algorithm
############################################################################################

@mustimplement "ColGenIteration" optimize_master_problem!()

@mustimplement "ColGenIteration" check_master_result()

@mustimplement "ColGenIteration" compute_sp_vars_red_costs()

@mustimplement "ColGenIteration" update_sp_vars_red_costs!()

@mustimplement "ColGenIteration" update_master_constrs_dual_vals!()

@mustimplement "ColGenIteration" optimize_pricing_problem!()

@mustimplement "ColGenIteration" check_pricing_result()

@mustimplement "ColGenIteration" compute_dual_bound!()

@mustimplement "ColGenIteration" compute_primal_bound!()

@mustimplement "ColGenIteration" get_master_solution()


"""
    run_colgen_iteration!(context, phase, reform)
"""
function run_colgen_iteration!()
    mast_result = optimize_master_problem!(context, phase, reform)
    stop = check_master_result(mast_result)

    pb = compute_primal_bound!(context, phase, reform)
    # essential cuts separation.
   
    red_costs = compute_sp_vars_red_costs(context, phase, reform, mast_dual_sol)

    update_sp_vars_red_costs!(context, sp, red_costs)
    update_master_constrs_dual_vals!(context, phase, reform, mast_dual_sol)

    for sp in get_dw_subprobs(reform)
        pricing_result = optimize_pricing_problem!(context, sp)
        stop = check_pricing_result(pricing_result)
    end

    db = compute_dual_bound!(context, phase, reform)

    return
end


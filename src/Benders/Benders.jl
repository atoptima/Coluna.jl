module Benders

include("../MustImplement/MustImplement.jl")
using .MustImplement

"""
Supertype for the objects to which belongs the implementation of the Benders cut generation and
that stores any kind of information during the execution of the Bender cut generation algorithm.
"""
abstract type AbstractBendersContext end

struct UnboundedError <: Exception end

include("interface.jl")

"Main loop of the Benders cut generation algorithm."
function run_benders_loop!(context, env; iter = 1)
    iteration = iter
    phase = nothing
    ip_primal_sol = nothing
    benders_iter_output = nothing
    setup_reformulation!(get_reform(context), env)
    while !stop_benders(context, benders_iter_output, iteration)
        benders_iter_output = run_benders_iteration!(context, phase, env, ip_primal_sol)
        after_benders_iteration(context, phase, env, iteration, benders_iter_output)
        iteration += 1
    end
    O = benders_output_type(context)
    return new_output(O, benders_iter_output)
end

"Runs one iteration of a Benders cut generation algorithm."
function run_benders_iteration!(context, phase, env, ip_primal_sol) ##TODO: remove arg phase from method signature 
    master = get_master(context)
    mast_result = optimize_master_problem!(master, context, env)
    O = benders_iteration_output_type(context)
    is_min_sense = is_minimization(context)

    # At least at the first iteration, if the master does not contain any Benders cut, the master will be
    # unbounded. The implementation must provide a routine to handle this case.
    # If the master is a MIP, we have to relax integrality constraints to retrieve a dual infeasibility
    # certificate.
    if is_unbounded(mast_result)
        mast_result = treat_unbounded_master_problem_case!(master, context, env)
    end

    # If the master is unbounded (even after treating unbounded master problem case), we
    # stop the algorithm because we don't handle unboundedness.
    if is_unbounded(mast_result)
        throw(UnboundedError())
    end

    # If the master is infeasible, it means the first level is infeasible and so the whole problem.
    # We stop Benders.
    if is_infeasible(mast_result)
        return new_iteration_output(O, is_min_sense, 0, nothing, true, false, nothing)
    end

    mast_primal_sol = get_primal_sol(mast_result)

    # Depending on whether the master was unbounded, we will solve a different separation problem.
    # See Lemma 2 of "Implementing Automatic Benders Decomposition in a Modern MIP Solver" (Bonami et al., 2020)
    # for more information.
    unbounded_master_case = is_certificate(mast_result)

    # Separation problems setup.
    for (_, sp) in get_benders_subprobs(context)
        if unbounded_master_case
            setup_separation_for_unbounded_master_case!(context, sp, mast_primal_sol)
        else
            update_sp_rhs!(context, sp, mast_primal_sol)
        end
    end

    # Solve the separation problems.
    # Here one subproblem = one dual sol = possibly one cut (multi-cuts approach). 
    generated_cuts = set_of_cuts(context)
    sep_sp_sols = set_of_sep_sols(context)
    second_stage_cost = 0.0
    for (_, sp_to_solve) in get_benders_subprobs(context)
        sep_result = optimize_separation_problem!(context, sp_to_solve, env, unbounded_master_case)

        if is_infeasible(sep_result)
            sep_result = treat_infeasible_separation_problem_case!(context, sp_to_solve, env, unbounded_master_case)
        end

        if is_unbounded(sep_result)
            throw(UnboundedError())
        end

        if is_infeasible(sep_result)
            return new_iteration_output(O, is_min_sense, 0, nothing, true, false, nothing)
        end

        second_stage_cost += get_obj_val(sep_result) ## update η = sum of the costs of the subproblems given a fixed 1st level solution

        # Push generated dual sol and cut in the context.
        nb_cuts_pushed = 0
        if push_in_set!(context, generated_cuts, sep_result)
            nb_cuts_pushed += 1
        else
            push_in_set!(context, sep_sp_sols, sep_result)
        end
    end

    if master_is_unbounded(context, second_stage_cost, unbounded_master_case)
        throw(UnboundedError())
    end

    cut_ids = insert_cuts!(get_reform(context), context, generated_cuts)
    nb_cuts_inserted = length(cut_ids)

    # Build primal solution
    ip_primal_sol = nothing
    if nb_cuts_inserted == 0
        ip_primal_sol = build_primal_solution(context, mast_primal_sol, sep_sp_sols)
    end
    
    master_obj_val = get_obj_val(mast_result)
    return new_iteration_output(O, is_min_sense, nb_cuts_inserted, ip_primal_sol, false, false, master_obj_val)
end

end
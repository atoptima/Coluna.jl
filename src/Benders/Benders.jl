module Benders

include("../MustImplement/MustImplement.jl")
using .MustImplement

abstract type AbstractBendersContext end

@mustimplement "Benders" is_minimization(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_reform(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_master(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_benders_subprobs(context) = nothing

@mustimplement "Benders" optimize_master_problem!(master, context, env) = nothing

# Master solution
@mustimplement "Benders" is_unbounded(res) = nothing

@mustimplement "Benders" get_primal_sol(res) = nothing

# If the master is unbounded
@mustimplement "Benders" treat_unbounded_master_problem!(master, context, env) = nothing

# second stage variable costs
@mustimplement "Benders" set_second_stage_var_costs_to_zero!(context) = nothing

@mustimplement "Benders" reset_second_stage_var_costs!(context) = nothing


@mustimplement "Benders" update_sp_rhs!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" set_sp_rhs_to_zero!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" set_of_cuts(context) = nothing

@mustimplement "Benders" optimize_separation_problem!(context, sp_to_solve, env) = nothing

@mustimplement "Benders" get_dual_sol(res) = nothing

@mustimplement "Benders" update_sp_dual_vars!(context, sp_to_solve, dual_sol) = nothing

@mustimplement "Benders" push_in_set!(context, generated_cuts, dual_sol) = nothing

@mustimplement "Benders" insert_cuts!(reform, context, generated_cuts) = nothing

@mustimplement "Benders" benders_iteration_output_type(::AbstractBendersContext) = nothing

abstract type AbstractBendersIterationOutput end

@mustimplement "Benders" new_iteration_output(::Type{<:AbstractBendersIterationOutput}, is_min_sense, nb_cuts_inserted, infeasible_master, infeasible_subproblem, time_limit_reached, master_obj_val) = nothing

@mustimplement "Benders" after_benders_iteration(::AbstractBendersContext, phase, env, iteration, benders_iter_output) = nothing

@mustimplement "Benders" stop_benders(::AbstractBendersContext, benders_iter_output, iteration) = nothing

@mustimplement "Benders" benders_output_type(::AbstractBendersContext) = nothing

abstract type AbstractBendersOutput end

@mustimplement "Benders" new_output(::Type{<:AbstractBendersOutput}, benders_iter_output) = nothing

@mustimplement "BendersMasterResult" get_obj_val(master_res) = nothing

@mustimplement "Benders" setup_reformulation!(reform, env) = nothing

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

function run_benders_iteration!(context, phase, env, ip_primal_sol)
    master = get_master(context)
    mast_result = optimize_master_problem!(master, context, env)
    certificate = false

    # At first iteration, if the master does not contain any Benders cut, the master will be
    # unbounded. The implementation must provide a routine to handle this case.
    if is_unbounded(mast_result)
        mast_result, certificate = treat_unbounded_master_problem!(master, context, env)
    end

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)

    for (_, sp) in get_benders_subprobs(context)
        # Right-hand-side of linking constraints is not updated in the same way whether the
        # master returns a dual infeasibility certificate or a primal solution.
        # See Lemma 2 of "Implementing Automatic Benders Decomposition in a Modern MIP Solver" (Bonami et al., 2020)
        if certificate
            set_sp_rhs_to_zero!(context, sp, mast_primal_sol)
        else
            update_sp_rhs!(context, sp, mast_primal_sol)
        end
    end

    generated_cuts = set_of_cuts(context)
    for (sp_id, sp_to_solve) in get_benders_subprobs(context)
        sep_result = optimize_separation_problem!(context, sp_to_solve, env)

        # dual_sol = get_dual_sol(sep_result)
        # if isnothing(dual_sol)
        #     error("no dual solution to separation subproblem.")
        # end

        nb_cuts_pushed = 0
        if push_in_set!(context, generated_cuts, sep_result)
            nb_cuts_pushed += 1
        end
    end

    cut_ids = insert_cuts!(get_reform(context), context, generated_cuts)
    nb_cuts_inserted = length(cut_ids)
    O = benders_iteration_output_type(context)
    is_min_sense = is_minimization(context)
    master_obj_val = get_obj_val(mast_result)
    return new_iteration_output(O, is_min_sense, nb_cuts_inserted, false, false, false, master_obj_val)
end

end
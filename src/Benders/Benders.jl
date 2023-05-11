module Benders

include("../MustImplement/MustImplement.jl")
using .MustImplement

abstract type AbstractBendersContext end

struct UnboundedError <: Exception end

@mustimplement "Benders" is_minimization(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_reform(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_master(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_benders_subprobs(context) = nothing

@mustimplement "Benders" optimize_master_problem!(master, context, env) = nothing

# Master solution
@mustimplement "Benders" is_unbounded(res) = nothing

@mustimplement "Benders" is_infeasible(res) = nothing

@mustimplement "Benders" is_certificate(res) = nothing

@mustimplement "Benders" get_primal_sol(res) = nothing

# If the master is unbounded
@mustimplement "Benders" treat_unbounded_master_problem!(master, context, env) = nothing

# second stage variable costs
@mustimplement "Benders" set_second_stage_var_costs_to_zero!(context) = nothing

@mustimplement "Benders" reset_second_stage_var_costs!(context) = nothing


@mustimplement "Benders" update_sp_rhs!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" set_sp_rhs_to_zero!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" set_of_cuts(context) = nothing

@mustimplement "Benders" set_of_sep_sols(context) = nothing

@mustimplement "Benders" optimize_separation_problem!(context, sp_to_solve, env, unbounded_master, p) = nothing

@mustimplement "Benders" get_dual_sol(res) = nothing

@mustimplement "Benders" update_sp_dual_vars!(context, sp_to_solve, dual_sol) = nothing

@mustimplement "Benders" push_in_set!(context, generated_cuts, dual_sol) = nothing

@mustimplement "Benders" insert_cuts!(reform, context, generated_cuts) = nothing

@mustimplement "Benders" benders_iteration_output_type(::AbstractBendersContext) = nothing

abstract type AbstractBendersIterationOutput end

@mustimplement "Benders" new_iteration_output(::Type{<:AbstractBendersIterationOutput}, is_min_sense, nb_cuts_inserted, ip_primal_sol, infeasible, time_limit_reached, master_obj_val) = nothing

@mustimplement "Benders" after_benders_iteration(::AbstractBendersContext, phase, env, iteration, benders_iter_output) = nothing

@mustimplement "Benders" stop_benders(::AbstractBendersContext, benders_iter_output, iteration) = nothing

@mustimplement "Benders" benders_output_type(::AbstractBendersContext) = nothing

abstract type AbstractBendersOutput end

@mustimplement "Benders" new_output(::Type{<:AbstractBendersOutput}, benders_iter_output) = nothing

@mustimplement "BendersMasterResult" get_obj_val(master_res) = nothing

@mustimplement "Benders" setup_reformulation!(reform, env) = nothing

@mustimplement "Benders" build_primal_solution(context, mast_primal_sol, sep_sp_sols) = nothing

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
    O = benders_iteration_output_type(context)
    is_min_sense = is_minimization(context)

    # At first iteration, if the master does not contain any Benders cut, the master will be
    # unbounded. The implementation must provide a routine to handle this case.
    if is_unbounded(mast_result)
        mast_result = treat_unbounded_master_problem!(master, context, env)
    end

    if is_unbounded(mast_result)
        throw(UnboundedError())
    end

    if is_infeasible(mast_result)
        return new_iteration_output(O, is_min_sense, 0, nothing, true, false, nothing)
    end

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)

    for (_, sp) in get_benders_subprobs(context)
        # Right-hand-side of linking constraints is not updated in the same way whether the
        # master returns a dual infeasibility certificate or a primal solution.
        # See Lemma 2 of "Implementing Automatic Benders Decomposition in a Modern MIP Solver" (Bonami et al., 2020)
        if is_certificate(mast_result)
            set_sp_rhs_to_zero!(context, sp, mast_primal_sol)
        else
            update_sp_rhs!(context, sp, mast_primal_sol)
        end
    end

    generated_cuts = set_of_cuts(context)
    sep_sp_sols = set_of_sep_sols(context)
    for (_, sp_to_solve) in get_benders_subprobs(context)
        sep_result = optimize_separation_problem!(context, sp_to_solve, env, is_certificate(mast_result), mast_primal_sol)

        if is_unbounded(sep_result)
            throw(UnboundedError())
        end

        if is_infeasible(sep_result)
            return new_iteration_output(O, is_min_sense, 0, nothing, true, false, nothing)
        end

        nb_cuts_pushed = 0
        if push_in_set!(context, generated_cuts, sep_result)
            nb_cuts_pushed += 1
        else
            push_in_set!(context, sep_sp_sols, sep_result)
        end
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
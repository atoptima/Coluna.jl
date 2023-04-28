module Benders

include("../MustImplement/MustImplement.jl")
using .MustImplement

abstract type AbstractBendersContext end

@mustimplement "Benders" get_reform(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_master(context::AbstractBendersContext) = nothing

@mustimplement "Benders" get_benders_subprobs(context) = nothing

@mustimplement "Benders" optimize_master_problem!(master, context, env) = nothing

# Master solution
@mustimplement "Benders" is_unbounded(res) = nothing

@mustimplement "Benders" get_primal_sol(res) = nothing


# second stage variable costs
@mustimplement "Benders" set_second_stage_var_costs_to_zero!(context) = nothing

@mustimplement "Benders" reset_second_stage_var_costs!(context) = nothing


@mustimplement "Benders" update_sp_rhs!(context, sp, mast_primal_sol) = nothing

@mustimplement "Benders" set_of_cuts(context) = nothing

@mustimplement "Benders" optimize_separation_problem!(context, sp_to_solve, env) = nothing

@mustimplement "Benders" get_dual_sol(res) = nothing

@mustimplement "Benders" update_sp_dual_vars!(context, sp_to_solve, dual_sol) = nothing

@mustimplement "Benders" push_in_set!(context, generated_cuts, dual_sol) = nothing

@mustimplement "Benders" insert_cuts!(reform, context, generated_cuts) = nothing

function run_benders_iteration!(context, phase, env, ip_primal_sol)
    master = get_master(context)
    mast_result = optimize_master_problem!(master, context, env)
    @show mast_result

    # At first iteration, if the master does not contain any Benders cut, the master will be
    # unbounded. we therefore solve the master by setting the cost of the second stage cost
    # variable to 0 so that the problem won't be unbounded anymore.
    if is_unbounded(mast_result)
        set_second_stage_var_costs_to_zero!(context)
        mast_result = optimize_master_problem!(master, context, env)
        reset_second_stage_var_costs!(context)
    end

    # Master primal solution
    mast_primal_sol = get_primal_sol(mast_result)

    for (_, sp) in get_benders_subprobs(context)
        update_sp_rhs!(context, sp, mast_primal_sol)
    end

    generated_cuts = set_of_cuts(context)
    for (sp_id, sp_to_solve) in get_benders_subprobs(context)
        sep_result = optimize_separation_problem!(context, sp_to_solve, env)

        dual_sol = get_dual_sol(sep_result)
        if isnothing(dual_sol)
            error("no dual solution to separation subproblem.")
        end

        nb_cuts_pushed = 0
        if push_in_set!(context, generated_cuts, sep_result)
            nb_cuts_pushed += 1
        end
    end

    cut_ids = insert_cuts!(get_reform(context), context, generated_cuts)
    @show master
    @show cut_ids
    return
end

end
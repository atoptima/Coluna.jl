"""
    BendersPrinterContext(reformulation, algo_params) -> BendersPrinterContext

Creates a context to run the default implementation of the Benders algorithm
together with a printer that prints information about the algorithm execution.
"""
mutable struct BendersPrinterContext
    inner::BendersContext
    sp_elapsed_time::Float64
    mst_elapsed_time::Float64
    print::Bool
    debug_mode::Bool
    debug_print_master::Bool
    debug_print_master_primal_solution::Bool
    debug_print_master_dual_solution::Bool
    debug_print_subproblem::Bool
    debug_print_subproblem_primal_solution::Bool
    debug_print_subproblem_dual_solution::Bool
    debug_print_generated_cuts::Bool
end

function BendersPrinterContext(
    reform, alg;
    print = false,
    debug_print_master = false,
    debug_print_master_primal_solution = false,
    debug_print_master_dual_solution = false,
    debug_print_subproblem = false,
    debug_print_subproblem_primal_solution = false,
    debug_print_subproblem_dual_solution = false,
    debug_print_generated_cuts = false,
)
    debug_mode = debug_print_master ||
        debug_print_master_primal_solution ||
        debug_print_subproblem ||
        debug_print_subproblem_primal_solution ||
        debug_print_subproblem_dual_solution ||
        debug_print_generated_cuts
    return BendersPrinterContext(
        BendersContext(reform, alg),
        0.0,
        0.0,
        print,
        debug_mode,
        debug_print_master,
        debug_print_master_primal_solution,
        debug_print_master_dual_solution,
        debug_print_subproblem,
        debug_print_subproblem_primal_solution,
        debug_print_subproblem_dual_solution,
        debug_print_generated_cuts,
    )
end

Benders.is_minimization(ctx::BendersPrinterContext) = Benders.is_minimization(ctx.inner)
Benders.get_reform(ctx::BendersPrinterContext) = Benders.get_reform(ctx.inner)
Benders.get_master(ctx::BendersPrinterContext) = Benders.get_master(ctx.inner)
Benders.get_benders_subprobs(ctx::BendersPrinterContext) = Benders.get_benders_subprobs(ctx.inner)

function Benders.optimize_master_problem!(master, ctx::BendersPrinterContext, env)
    if ctx.debug_print_master || ctx.debug_print_master_primal_solution || ctx.debug_print_master_dual_solution
        println(crayon"bold blue", repeat('-', 80), crayon"reset")
    end
    ctx.mst_elapsed_time = @elapsed begin
    result = Benders.optimize_master_problem!(master, ctx.inner, env)
    end
    if ctx.debug_print_master
        print(crayon"bold underline blue", "Master problem:", crayon"!bold !underline")
        @show master
        print(crayon"reset")
    end 
    if ctx.debug_print_master_primal_solution
        print(crayon"bold underline blue", "Master primal solution:", crayon"!bold !underline")
        @show Benders.get_primal_sol(result)
        print(crayon"reset")
    end
    if ctx.debug_print_master_dual_solution
        print(crayon"bold underline blue", "Master dual solution:", crayon"!bold !underline")
        @show Benders.get_dual_sol(result)
        print(crayon"reset")
    end
    if ctx.debug_print_master || ctx.debug_print_master_primal_solution || ctx.debug_print_master_dual_solution
        println(crayon"bold blue", repeat('-', 80), crayon"reset")
    end
    return result
end

function Benders.treat_unbounded_master_problem_case!(master, ctx::BendersPrinterContext, env)
    result = Benders.treat_unbounded_master_problem_case!(master, ctx.inner, env)
    if ctx.debug_print_master || ctx.debug_print_master_primal_solution || ctx.debug_print_master_dual_solution
        println(crayon"bold blue", repeat('-', 80), crayon"reset")
        println(crayon"bold underline blue", "Treat unbounded master", crayon"reset")
        @show master
        print(crayon"bold underline blue", "Master primal solution:", crayon"!bold !underline")
        @show Benders.get_primal_sol(result)
        print(crayon"reset")
        println(crayon"bold blue", repeat('-', 80), crayon"reset")
    end
    return result
end

Benders.update_sp_rhs!(ctx::BendersPrinterContext, sp, primal_sol) = Benders.update_sp_rhs!(ctx.inner, sp, primal_sol)
Benders.setup_separation_for_unbounded_master_case!(ctx::BendersPrinterContext, sp, primal_sol) = Benders.setup_separation_for_unbounded_master_case!(ctx.inner, sp, primal_sol)
Benders.set_of_cuts(ctx::BendersPrinterContext) = Benders.set_of_cuts(ctx.inner)
Benders.set_of_sep_sols(ctx::BendersPrinterContext) = Benders.set_of_sep_sols(ctx.inner)

function Benders.optimize_separation_problem!(ctx::BendersPrinterContext, sp::Formulation{BendersSp}, env, unbounded_master)
    if ctx.debug_print_subproblem || ctx.debug_print_subproblem_primal_solution || ctx.debug_print_subproblem_dual_solution
        println(crayon"bold green", repeat('-', 80), crayon"reset")
    end
    if ctx.debug_print_subproblem
        print(crayon"bold underline green", "Separation problem (unbounded master = $unbounded_master):", crayon"!bold !underline")
        @show sp
        print(crayon"reset")
    end
    ctx.sp_elapsed_time = @elapsed begin
    result = Benders.optimize_separation_problem!(ctx.inner, sp, env, unbounded_master)
    end
    if ctx.debug_print_subproblem_primal_solution
        print(crayon"bold underline green", "Separation problem primal solution:", crayon"!bold !underline")
        @show Benders.get_primal_sol(result)
        print(crayon"reset")
    end
    if ctx.debug_print_subproblem_dual_solution
        print(crayon"bold underline green", "Separation problem dual solution:", crayon"!bold !underline")
        @show Benders.get_dual_sol(result)
        print(crayon"reset")
    end
    if ctx.debug_print_subproblem || ctx.debug_print_subproblem_primal_solution || ctx.debug_print_subproblem_dual_solution
        println(crayon"bold green", repeat('-', 80), crayon"reset")
    end
    return result
end

function Benders.treat_infeasible_separation_problem_case!(ctx::BendersPrinterContext, sp, env, unbounded_master_case)
    result = Benders.treat_infeasible_separation_problem_case!(ctx.inner, sp, env, unbounded_master_case)
    if ctx.debug_print_subproblem || ctx.debug_print_subproblem_primal_solution || ctx.debug_print_subproblem_dual_solution
        println(crayon"bold green", repeat('-', 80), crayon"reset")
    end
    if ctx.debug_print_subproblem
        print(crayon"bold underline green", "Phase 1 Separation problem (unbounded_master = $unbounded_master_case):", crayon"!bold !underline")
        @show sp
        print(crayon"reset")
    end
    ctx.sp_elapsed_time = @elapsed begin
    result = Benders.treat_infeasible_separation_problem_case!(ctx.inner, sp, env, unbounded_master_case)
    end
    if ctx.debug_print_subproblem_primal_solution
        print(crayon"bold underline green", "Separation problem primal solution:", crayon"!bold !underline")
        @show Benders.get_primal_sol(result)
        print(crayon"reset")
    end
    if ctx.debug_print_subproblem_dual_solution
        print(crayon"bold underline green", "Separation problem dual solution:", crayon"!bold !underline")
        @show Benders.get_dual_sol(result)
        print(crayon"reset")
    end
    if ctx.debug_print_subproblem || ctx.debug_print_subproblem_primal_solution || ctx.debug_print_subproblem_dual_solution
        println(crayon"bold green", repeat('-', 80), crayon"reset")
    end
    return result
end

Benders.push_in_set!(ctx::BendersPrinterContext, set, sep_result) = Benders.push_in_set!(ctx.inner, set, sep_result)

function Benders.insert_cuts!(reform, ctx::BendersPrinterContext, cuts)
    cut_ids = Benders.insert_cuts!(reform, ctx.inner, cuts)
end

Benders.benders_iteration_output_type(ctx::BendersPrinterContext) = Benders.benders_iteration_output_type(ctx.inner)

Benders.stop_benders(ctx::BendersPrinterContext, benders_iter_output, benders_iteration) = Benders.stop_benders(ctx.inner, benders_iter_output, benders_iteration)

Benders.benders_output_type(ctx::BendersPrinterContext) = Benders.benders_output_type(ctx.inner)

function _benders_iter_str(iteration, benders_iter_output, sp_time::Float64, mst_time::Float64, optim_time::Float64)
    master::Float64 = isnothing(benders_iter_output.master) ? NaN : benders_iter_output.master
    nb_new_cuts = benders_iter_output.nb_new_cuts
    return @sprintf(
        "<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cuts=%2i> <master=%10.4f>",
        iteration, optim_time, mst_time, sp_time, nb_new_cuts, master
    )
end

function Benders.after_benders_iteration(ctx::BendersPrinterContext, phase, env, iteration, benders_iter_output)
    println(_benders_iter_str(iteration, benders_iter_output, ctx.sp_elapsed_time, ctx.mst_elapsed_time, elapsed_optim_time(env)))
    if ctx.debug_mode
        println(crayon"bold red", repeat('-', 30), " end of iteration ", iteration, " ", repeat('-', 30), crayon"reset")
    end
    return
end

function Benders.build_primal_solution(context::BendersPrinterContext, mast_primal_sol, sep_sp_sols)
    return Benders.build_primal_solution(context.inner, mast_primal_sol, sep_sp_sols)
end

Benders.master_is_unbounded(ctx::BendersPrinterContext, second_stage_cost, unbounded_master_case) = Benders.master_is_unbounded(ctx.inner, second_stage_cost, unbounded_master_case)

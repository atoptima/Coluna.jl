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

function Benders.treat_unbounded_master_problem!(master, ctx::BendersPrinterContext, env)
    result, c = Benders.treat_unbounded_master_problem!(master, ctx.inner, env)
    if ctx.debug_print_master || ctx.debug_print_master_primal_solution || ctx.debug_print_master_dual_solution
        println(crayon"bold blue", repeat('-', 80), crayon"reset")
        println(crayon"bold underline blue", "Treat unbounded master", crayon"reset")
        @show master
        print(crayon"bold underline blue", "Master primal solution:", crayon"!bold !underline")
        @show Benders.get_primal_sol(result)
        print(crayon"reset")
        println(crayon"bold blue", repeat('-', 80), crayon"reset")
    end
    return result, c
end

Benders.set_second_stage_var_costs_to_zero!(ctx::BendersPrinterContext) = Benders.set_second_stage_var_costs_to_zero!(ctx.inner)
Benders.reset_second_stage_var_costs!(ctx::BendersPrinterContext) = Benders.reset_second_stage_var_costs!(ctx.inner)
Benders.update_sp_rhs!(ctx::BendersPrinterContext, sp, primal_sol) = Benders.update_sp_rhs!(ctx.inner, sp, primal_sol)
Benders.set_sp_rhs_to_zero!(ctx::BendersPrinterContext, sp, primal_sol) = Benders.set_sp_rhs_to_zero!(ctx.inner, sp, primal_sol)
Benders.set_of_cuts(ctx::BendersPrinterContext) = Benders.set_of_cuts(ctx.inner)

function Benders.optimize_separation_problem!(ctx::BendersPrinterContext, sp::Formulation{BendersSp}, env)
    if ctx.debug_print_subproblem || ctx.debug_print_subproblem_primal_solution || ctx.debug_print_subproblem_dual_solution
        println(crayon"bold green", repeat('-', 80), crayon"reset")
    end
    if ctx.debug_print_subproblem
        print(crayon"bold underline green", "Separation problem:", crayon"!bold !underline")
        @show sp
        print(crayon"reset")
    end
    ctx.sp_elapsed_time = @elapsed begin
    result = Benders.optimize_separation_problem!(ctx.inner, sp, env)
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
    master::Float64 = benders_iter_output.master
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
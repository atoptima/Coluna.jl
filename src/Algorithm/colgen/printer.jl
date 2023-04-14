mutable struct ColGenPrinterContext <: ColGen.AbstractColGenContext
    inner::ColGenContext
    phase::Int
    mst_elapsed_time::Float64
    sp_elapsed_time::Float64
    print_column_reduced_cost::Bool

    function ColGenPrinterContext(
        reform, alg;
        print_column_reduced_cost = true
    )
        inner = ColGenContext(reform, alg)
        new(inner, 3, 0.0, 0.0, print_column_reduced_cost)
    end
end

ColGen.get_reform(ctx::ColGenPrinterContext) = ColGen.get_reform(ctx.inner)
ColGen.get_master(ctx::ColGenPrinterContext) = ColGen.get_master(ctx.inner)
ColGen.is_minimization(ctx::ColGenPrinterContext) = ColGen.is_minimization(ctx.inner)
ColGen.get_pricing_subprobs(ctx::ColGenPrinterContext) = ColGen.get_pricing_subprobs(ctx.inner)

ColGen.new_phase_iterator(ctx::ColGenPrinterContext) = ColGen.new_phase_iterator(ctx.inner)

_phase_type_to_number(::ColGenPhase1) = 1
_phase_type_to_number(::ColGenPhase2) = 2
_phase_type_to_number(::ColGenPhase3) = 3
function ColGen.setup_context!(ctx::ColGenPrinterContext, phase::ColGen.AbstractColGenPhase)
    ctx.phase = _phase_type_to_number(phase)
    return ColGen.setup_context!(ctx.inner, phase)
end

function ColGen.optimize_master_lp_problem!(master, ctx::ColGenPrinterContext, env)
    ctx.mst_elapsed_time = @elapsed begin
        output = ColGen.optimize_master_lp_problem!(master, ctx.inner, env)
    end
    return output
end

function ColGen.update_master_constrs_dual_vals!(ctx::ColGenPrinterContext, phase, reform, master_lp_dual_sol)
    return ColGen.update_master_constrs_dual_vals!(ctx.inner, phase, reform, master_lp_dual_sol)
end

ColGen.check_primal_ip_feasibility!(mast_primal_sol, ctx::ColGenPrinterContext, phase, reform, env) = ColGen.check_primal_ip_feasibility!(mast_primal_sol, ctx.inner, phase, reform, env)
ColGen.update_inc_primal_sol!(ctx::ColGenPrinterContext, ip_primal_sol) = ColGen.update_inc_primal_sol!(ctx.inner, ip_primal_sol)

ColGen.get_subprob_var_orig_costs(ctx::ColGenPrinterContext) = ColGen.get_subprob_var_orig_costs(ctx.inner)
ColGen.get_subprob_var_coef_matrix(ctx::ColGenPrinterContext) = ColGen.get_subprob_var_coef_matrix(ctx.inner)

function ColGen.update_sp_vars_red_costs!(ctx::ColGenPrinterContext, sp::Formulation{DwSp}, red_costs)
    return ColGen.update_sp_vars_red_costs!(ctx.inner, sp, red_costs)
end

function ColGen.insert_columns!(reform, ctx::ColGenPrinterContext, phase, columns)
    col_ids = ColGen.insert_columns!(reform, ctx.inner, phase, columns)
    if ctx.print_column_reduced_cost
        _calculate_column_reduced_cost(ColGen.get_reform(ctx), col_ids)
    end
    return col_ids
end

ColGen.compute_sp_init_db(ctx::ColGenPrinterContext, sp::Formulation{DwSp}) = ColGen.compute_sp_init_db(ctx.inner, sp)

ColGen.set_of_columns(ctx::ColGenPrinterContext) = ColGen.set_of_columns(ctx.inner)

function _calculate_column_reduced_cost(reform, col_ids)
    @show typeof(reform)
    @show col_ids
    error("Good luck")
end

function ColGen.push_in_set!(ctx::ColGenPrinterContext, set, col)
    return ColGen.push_in_set!(ctx.inner, set, col)
end

function ColGen.optimize_pricing_problem!(ctx::ColGenPrinterContext, sp::Formulation{DwSp}, env, master_dual_sol)
    ctx.sp_elapsed_time = @elapsed begin
        output = ColGen.optimize_pricing_problem!(ctx.inner, sp, env, master_dual_sol)
    end
    return output
end

function ColGen.compute_dual_bound(ctx::ColGenPrinterContext, phase, master_lp_obj_val, sp_dbs, master_dual_sol)
    return ColGen.compute_dual_bound(ctx.inner, phase, master_lp_obj_val, sp_dbs, master_dual_sol)
end

function ColGen.colgen_iteration_output_type(ctx::ColGenPrinterContext)
    return ColGen.colgen_iteration_output_type(ctx.inner)
end

function ColGen.stop_colgen_phase(ctx::ColGenPrinterContext, phase, env, colgen_iter_output, colgen_iteration, cutsep_iteration)
    return ColGen.stop_colgen_phase(ctx.inner, phase, env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end

ColGen.before_colgen_iteration(ctx::ColGenPrinterContext, phase) = nothing

function _get_inc_pb(ctx::ColGenPrinterContext)
    sol = ctx.inner.incumbent_primal_solution
    if isnothing(sol)
        return Inf
    end
    return getvalue(sol)
end

function _iter_str(ctx::ColGenPrinterContext, phase, env, colgen_iteration, colgen_iter_output::ColGen.AbstractColGenIterationOutput)
    mlp = colgen_iter_output.mlp
    db = colgen_iter_output.db
    pb = _get_inc_pb(ctx)

    phase_string = "  "
    if ctx.phase == 1
        phase_string = "# "
    elseif ctx.phase == 2
        phase_string = "##"
    end

    smoothalpha = 0.0 # not implemented yet.
    nb_new_col = ColGen.get_nb_new_cols(colgen_iter_output)
    sp_time = ctx.sp_elapsed_time
    mst_time = ctx.mst_elapsed_time
    iteration = colgen_iteration
    optim_time = elapsed_optim_time(env)
    
    return @sprintf(
        "%s<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cols=%2i> <al=%5.2f> <DB=%10.4f> <mlp=%10.4f> <PB=%.4f>",
        phase_string, iteration, optim_time, mst_time, sp_time, nb_new_col, smoothalpha, db, mlp, pb
    )
end

function ColGen.after_colgen_iteration(ctx::ColGenPrinterContext, phase, env, colgen_iteration, colgen_iter_output)
    println(_iter_str(ctx, phase, env, colgen_iteration, colgen_iter_output))
    return
end

ColGen.colgen_output_type(::ColGenPrinterContext) = ColGenOutput
ColGen.colgen_phase_output_type(::ColGenPrinterContext) = ColGenPhaseOutput
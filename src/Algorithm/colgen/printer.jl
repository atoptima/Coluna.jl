mutable struct ColGenPrinterContext <: ColGen.AbstractColGenContext
    inner::ColGenContext
    phase::Int

    function ColGenPrinterContext(reform, alg)
        inner = ColGenContext(reform, alg)
        new(inner, 3)
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
    output = ColGen.optimize_master_lp_problem!(master, ctx.inner, env)
    return output
end

function ColGen.update_master_constrs_dual_vals!(ctx::ColGenPrinterContext, phase, reform, master_lp_dual_sol)
    return ColGen.update_master_constrs_dual_vals!(ctx.inner, phase, reform, master_lp_dual_sol)
end

ColGen.get_subprob_var_orig_costs(ctx::ColGenPrinterContext) = ColGen.get_subprob_var_orig_costs(ctx.inner)
ColGen.get_subprob_var_coef_matrix(ctx::ColGenPrinterContext) = ColGen.get_subprob_var_coef_matrix(ctx.inner)

function ColGen.update_sp_vars_red_costs!(ctx::ColGenPrinterContext, sp::Formulation{DwSp}, red_costs)
    return ColGen.update_sp_vars_red_costs!(ctx.inner, sp, red_costs)
end

function ColGen.insert_columns!(reform, ctx::ColGenPrinterContext, phase, columns)
    return ColGen.insert_columns!(reform, ctx.inner, phase, columns)
end

ColGen.compute_sp_init_db(ctx::ColGenPrinterContext, sp::Formulation{DwSp}) = ColGen.compute_sp_init_db(ctx.inner, sp)

ColGen.set_of_columns(ctx::ColGenPrinterContext) = ColGen.set_of_columns(ctx.inner)

function ColGen.optimize_pricing_problem!(ctx::ColGenPrinterContext, sp::Formulation{DwSp}, env, master_dual_sol)
    output = ColGen.optimize_pricing_problem!(ctx.inner, sp, env, master_dual_sol)
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

function ColGen.after_colgen_iteration(ctx::ColGenPrinterContext, phase, colgen_iter_output)
    mlp = colgen_iter_output.mlp
    db = colgen_iter_output.db
    pb = 666

    phase_string = "  "
    if ctx.phase == 1
        phase_string = "# "
    elseif ctx.phase == 2
        phase_string = "##"
    end

    smoothalpha = 0.0
    nb_new_col = 0.0
    sp_time = 0.0
    mst_time = 0.0
    iteration = 0.0
    elapsed_optim_time = 0.0

    @printf(
        "%s<it=%3i> <et=%5.2f> <mst=%5.2f> <sp=%5.2f> <cols=%2i> <al=%5.2f> <DB=%10.4f> <mlp=%10.4f> <PB=%.4f>\n",
        phase_string, iteration, elapsed_optim_time, mst_time, sp_time, nb_new_col, smoothalpha, db, mlp, pb
    )
    return
end

ColGen.colgen_output_type(::ColGenPrinterContext) = ColGenOutput
ColGen.colgen_phase_output_type(::ColGenPrinterContext) = ColGenPhaseOutput
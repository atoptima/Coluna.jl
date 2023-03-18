# Master resolution
function ColGen.optimize_master_lp_problem!(master, ctx::ColGenContext, env)

end

# ColGen.get_obj_val(master_res) = nothing
# ColGen.get_primal_sol(master_res) = nothing
# ColGen.get_dual_sol(master_res) = nothing

function ColGen.update_master_constrs_dual_vals!(ctx::ColGenContext, phase, reform, master_lp_dual_sol)

end

function ColGen.check_primal_ip_feasibility(master_lp_primal_sol, phase, reform)

end

# Reduced costs calculation
ColGen.get_orig_costs(ctx::ColGenContext) = nothing
ColGen.get_coef_matrix(ctx::ColGenContext) = nothing

function ColGen.update_sp_vars_red_costs!(ctx::ColGenContext, sp, red_costs)

end

# Columns insertion
function insert_columns!(reform, ctx::ColGenContext, phase, columns)

end

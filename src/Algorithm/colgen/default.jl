struct ColGenContext <: ColGen.AbstractColGenContext
    reform::Reformulation


    # # Information to solve the master
    # master_solve_alg
    # master_optimizer_id

    # # Memoization to compute reduced costs (this is a precompute)
    # redcost_mem
end

ColGen.get_reform(ctx::ColGenContext) = ctx.reform
ColGen.get_master(ctx::ColGenContext) = getmaster(ctx.reform)
ColGen.get_pricing_subprobs(ctx::ColGenContext) = get_dw_pricing_sps(ctx.reform)

include("iteration.jl")




# # Placeholder methods:  
# ColGen.before_colgen_iteration(::ColGenContext, _, _) = nothing
# ColGen.after_colgen_iteration(::ColGenContext, _, _, _) = nothing

# ######### Column generation iteration
# function ColGen.optimize_master_lp_problem!(master, context, env)
#     println("\e[31m optimize master lp problem \e[00m")
#     input = OptimizationState(master, ip_primal_bound=0.0) # TODO : ip_primal_bound=get_ip_primal_bound(cg_optstate)
#     return run!(context.master_solve_alg, env, master, input, context.master_optimizer_id)
# end

# #get_primal_sol(mast_result)

# function ColGen.check_primal_ip_feasibility(ctx, mast_lp_primal_sol)
#     println("\e[31m check primal ip feasibility \e[00m")
#     return !contains(mast_lp_primal_sol, varid -> isanArtificialDuty(getduty(varid))) &&
#         isinteger(proj_cols_on_rep(mast_lp_primal_sol, getmodel(mast_lp_primal_sol)))
# end

# #update_inc_primal_sol!

# #get_dual_sol(mast_result)

# function ColGen.update_master_constrs_dual_vals!(ctx, master, smooth_dual_sol)
#     println("\e[32m update_master_constrs_dual_vals \e[00m")
#     # Set all dual value of all constraints to 0.
#     for constr in Iterators.values(getconstrs(master))
#         setcurincval!(master, constr, 0.0)
#     end
#     # Update constraints that have non-zero dual values.
#     for (constr_id, val) in smooth_dual_sol
#         setcurincval!(master, constr_id, val)
#     end
# end

# function ColGen.update_sp_vars_red_costs!(ctx, sp, red_costs)
#     println("\e[34m update_sp_vars_red_costs \e[00m")
#     for (var_id, _) in getvars(sp)
#         setcurcost!(sp, var_id, red_costs[var_id])
#     end
#     return
# end
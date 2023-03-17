struct ColGenContext <: ColGen.AbstractColGenContext
    # Information to solve the master
    master_solve_alg
    master_optimizer_id

    # Memoization to compute reduced costs (this is a precompute)
    redcost_mem
end

###############################################################################
# Sequence of phases
###############################################################################
struct ColunaColGenPhaseIterator <: ColGen.AbstractColGenPhaseIterator end

"""
Phase 1 sets the cost of variables to 0 except for artifical variables.
The goal is to find a solution to the master LP problem that has no artificial variables.
"""
struct ColGenPhase1 <: ColGen.AbstractColGenPhase end

"""
Phase 2 solves the master LP without artificial variables.
To starts, it requires a set of columns that forms a feasible solution to the LP master.
This set is found with phase 1.
"""
struct ColGenPhase2 <: ColGen.AbstractColGenPhase end

"""
Phase 3 is a mix of phase 1 and phase 2.
It sets a very large cost to artifical variable to force them to be removed from the master 
LP solution.
If the final master LP solution contains artifical variables either the master is infeasible
or the cost of artificial variables is not large enough. Phase 1 must be run.
"""
struct ColGenPhase3 <: ColGen.AbstractColGenPhase end

# Implementation of ColGenPhase interface
## Implementation of `initial_phase`.
ColGen.initial_phase(::ColunaColGenPhaseIterator) = ColGenPhase3()

## Implementation of `next_phase`.
function ColGen.next_phase(::ColunaColGenPhaseIterator, ::ColGenPhase1, ctx)
    # If master LP solution has no artificial vars, it means that the phase 1 has succeeded.
    # We have a set of columns that forms a feasible solution to the LP master and we can 
    # thus start phase 2.
    if !colgen_mast_lp_sol_has_art_vars(ctx)
        return ColGenPhase2()
    end
    return nothing
end

function ColGen.next_phase(::ColunaColGenPhaseIterator, ::ColGenPhase2, ctx)
    # The phase 2 is always the last phase of the column generation algorithm.
    # It means the algorithm converged or hit a user limit.
    return nothing
end

function ColGen.next_phase(::ColunaColGenPhaseIterator, ::ColGenPhase3, ctx)
    # Master LP solution has artificial vars.
    if colgen_mast_lp_sol_has_art_vars(ctx)
        return ColGenPhase1()
    end
    return nothing
end

## Methods used in the implementation and that we should mock in tests.
function colgen_mast_lp_sol_has_art_vars(ctx::ColGenContext)

end

## Implementatation of `setup_reformulation!`
## Phase 1 => non-artifical variables have cost equal to 0
function ColGen.setup_reformulation!(reform, ::ColGenPhase1)
    master = getmaster(reform)
    for (varid, _) in getvars(master)
        if !isanArtificialDuty(getduty(varid))
            setcurcost!(master, varid, 0.0)
        end
    end
    return
end

## Phase 2 => deactivate artifical variables and make sure that the cost of non-artifical
## variables is correct.
function ColGen.setup_reformulation!(reform, ::ColGenPhase2)
    master = getmaster(reform)
    for (varid, var) in getvars(master)
        if isanArtificialDuty(getduty(varid))
            deactivate!(master, varid)
        else
            setcurcost!(master, varid, getperencost(master, var))
        end
    end
    return
end

## Phase 3 => make sure artifical variables are active and cost is correct.
function ColGen.setup_reformulation!(reform, ::ColGenPhase3)
    master = getmaster(reform)
    for (varid, var) in getvars(master)
        if isanArtificialDuty(getduty(varid))
            activate!(master, varid)
        end
        setcurcost!(master, varid, getperencost(master, var))
    end
    return
end

######### Pricing strategy
struct ClassicPricingStrategy <: ColGen.AbstractPricingStrategy 
    subprobs::Dict{FormId, Formulation{DwSp}}
end

function ColGen.get_pricing_strategy(ctx::ColGen.AbstractColGenContext, _)
    ClassicPricingStrategy(Dict(i => sp for (i, sp) in ColGen.get_pricing_subprobs(ctx)))
end

ColGen.pricing_strategy_iterate(ps::ClassicPricingStrategy) = iterate(ps.subprobs)


######### Column generation

# Placeholder methods:  
ColGen.before_colgen_iteration(::ColGenContext, _, _) = nothing
ColGen.after_colgen_iteration(::ColGenContext, _, _, _) = nothing

######### Column generation iteration
function ColGen.optimize_master_lp_problem!(master, context, env)
    println("\e[31m optimize master lp problem \e[00m")
    input = OptimizationState(master, ip_primal_bound=0.0) # TODO : ip_primal_bound=get_ip_primal_bound(cg_optstate)
    return run!(context.master_solve_alg, env, master, input, context.master_optimizer_id)
end

#get_primal_sol(mast_result)

function ColGen.check_primal_ip_feasibility(ctx, mast_lp_primal_sol)
    println("\e[31m check primal ip feasibility \e[00m")
    return !contains(mast_lp_primal_sol, varid -> isanArtificialDuty(getduty(varid))) &&
        isinteger(proj_cols_on_rep(mast_lp_primal_sol, getmodel(mast_lp_primal_sol)))
end

#update_inc_primal_sol!

#get_dual_sol(mast_result)

function ColGen.update_master_constrs_dual_vals!(ctx, master, smooth_dual_sol)
    println("\e[32m update_master_constrs_dual_vals \e[00m")
    # Set all dual value of all constraints to 0.
    for constr in Iterators.values(getconstrs(master))
        setcurincval!(master, constr, 0.0)
    end
    # Update constraints that have non-zero dual values.
    for (constr_id, val) in smooth_dual_sol
        setcurincval!(master, constr_id, val)
    end
end

function ColGen.compute_sp_vars_red_costs(ctx, mast_lp_dual_sol)
    println("\e[34m compute_sp_vars_red_costs \e[00m")
    return ctx.redcost_mem.c - transpose(ctx.redcost_mem.A) * mast_lp_dual_sol
end

function ColGen.update_sp_vars_red_costs!(ctx, sp, red_costs)
    println("\e[34m update_sp_vars_red_costs \e[00m")
    for (var_id, _) in getvars(sp)
        setcurcost!(sp, var_id, red_costs[var_id])
    end
    return
end
struct ColGenContext <: ColGen.AbstractColGenContext
    reform::Reformulation
    optim_sense
    current_ip_primal_bound

    restr_master_solve_alg
    restr_master_optimizer_id::Int

    pricing_solve_alg

    reduced_cost_helper::ReducedCostsCalculationHelper

    show_column_already_inserted_warning::Bool
    throw_column_already_inserted_warning::Bool

    # # Information to solve the master
    # master_solve_alg
    # master_optimizer_id

    # # Memoization to compute reduced costs (this is a precompute)
    # redcost_mem
    function ColGenContext(reform, alg)
        rch = ReducedCostsCalculationHelper(getmaster(reform))
        return new(
            reform, 
            getobjsense(reform), 
            0.0, 
            alg.restr_master_solve_alg, 
            alg.restr_master_optimizer_id,
            alg.pricing_prob_solve_alg,
            rch,
            alg.show_column_already_inserted_warning,
            alg.throw_column_already_inserted_warning
        )
    end
end

ColGen.get_reform(ctx::ColGenContext) = ctx.reform
ColGen.get_master(ctx::ColGenContext) = getmaster(ctx.reform)
ColGen.get_pricing_subprobs(ctx::ColGenContext) = get_dw_pricing_sps(ctx.reform)


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

colgen_mast_lp_sol_has_art_vars(ctx) = false

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

# Implementatation of `setup_reformulation!`
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



# Master resolution

"""
    ColGenMasterResult{F,S}

Contains the solution to the master LP.
- `F` is the formulation type
- `S` is the objective sense Type
"""
struct ColGenMasterResult{F,S}
    result::OptimizationState{F,S}
end

# TODO: not type stable !!
function ColGen.optimize_master_lp_problem!(master, ctx::ColGenContext, env)
    rm_input = OptimizationState(master, ip_primal_bound=ctx.current_ip_primal_bound)
    opt_state = run!(ctx.restr_master_solve_alg, env, master, rm_input, ctx.restr_master_optimizer_id)
    return ColGenMasterResult(opt_state)
end

function ColGen.is_infeasible(master_res::ColGenMasterResult)
    status = getterminationstatus(master_res.result)
    return status == ClB.INFEASIBLE || status == ClB.INFEASIBLE_OR_UNBOUNDED
end

function ColGen.is_unbounded(master_res::ColGenMasterResult)
    status = getterminationstatus(master_res.result)
    return status == ClB.DUAL_INFEASIBLE || status == ClB.INFEASIBLE_OR_UNBOUNDED
end

ColGen.get_primal_sol(master_res::ColGenMasterResult) = get_best_lp_primal_sol(master_res.result)
ColGen.get_dual_sol(master_res::ColGenMasterResult) = get_best_lp_dual_sol(master_res.result)
ColGen.get_obj_val(master_res::ColGenMasterResult) = get_lp_primal_bound(master_res.result)

function ColGen.update_master_constrs_dual_vals!(ctx::ColGenContext, phase, reform, master_lp_dual_sol)

end

function ColGen.check_primal_ip_feasibility(master_lp_primal_sol, phase, reform)

end

# Reduced costs calculation
ColGen.get_subprob_var_orig_costs(ctx::ColGenContext) = ctx.reduced_cost_helper.dw_subprob_c
ColGen.get_subprob_var_coef_matrix(ctx::ColGenContext) = ctx.reduced_cost_helper.dw_subprob_A

function ColGen.update_sp_vars_red_costs!(ctx::ColGenContext, sp::Formulation{DwSp}, red_costs)
    for (var_id, _) in getvars(sp)
        setcurcost!(sp, var_id, red_costs[var_id])
    end
    return
end

# Columns insertion
function ColGen.insert_columns!(reform, ctx::ColGenContext, phase, columns)
    primal_sols_to_insert = PrimalSolution{Formulation{DwSp}}[]
    col_ids_to_activate = Set{VarId}()
    master = ColGen.get_master(ctx)
    for column in columns
        col_id = get_column_from_pool(column.column)
        if !isnothing(col_id)
            if haskey(master, col_id) && !iscuractive(master, col_id)
                push!(col_ids_to_activate, col_id)
            else
                in_master = haskey(master, col_id)
                is_active = iscuractive(master, col_id)
                warning = ColumnAlreadyInsertedColGenWarning(
                    in_master, is_active, column.red_cost, col_id, master, column.column.solution.model
                )
                if ctx.show_column_already_inserted_warning
                    @warn warning
                end
                if ctx.throw_column_already_inserted_warning
                    throw(warning)
                end
            end
        else
            push!(primal_sols_to_insert, column.column)
        end
    end

    nb_added_cols = 0
    nb_reactivated_cols = 0

    # Then, we add the new columns (i.e. not in the pool).
    for sol in primal_sols_to_insert
        col_id = insert_column!(master, sol, "MC")
        if phase == 1
            setcurcost!(master, col_id, 0.0)
        end
        nb_added_cols += 1
    end

    # And we reactivate the deactivated columns already generated.
    for col_id in col_ids_to_activate
        activate!(master, col_id)
        if phase == 1
            setcurcost!(master, col_id, 0.0)
        end
        nb_reactivated_cols += 1
    end

    return nb_added_cols + nb_reactivated_cols
end

#############################################################################
# Pricing strategy
#############################################################################
struct ClassicColGenPricingStrategy <: ColGen.AbstractPricingStrategy
    subprobs::Dict{FormId, Formulation{DwSp}}
end

ColGen.get_pricing_strategy(ctx::ColGen.AbstractColGenContext, _) = ClassicColGenPricingStrategy(ColGen.get_pricing_subprobs(ctx))
ColGen.pricing_strategy_iterate(ps::ClassicColGenPricingStrategy) = iterate(ps.subprobs)
ColGen.pricing_strategy_iterate(ps::ClassicColGenPricingStrategy, state) = iterate(ps.subprobs, state)

#############################################################################
# Column generation
#############################################################################
function ColGen.compute_sp_init_db(ctx::ColGenContext, sp::Formulation{DwSp})
    return ctx.optim_sense == MinSense ? -Inf : Inf
end

struct GeneratedColumn
    column::PrimalSolution{Formulation{DwSp}}
    red_cost::Float64
    min_obj::Bool # TODO remove when formulation will be parametrized by the sense.
    function GeneratedColumn(column, red_cost)
        min_obj = getobjsense(column.solution.model) == MinSense
        return new(column, red_cost, min_obj)
    end
end

"""
    A structure to store a collection of columns
"""
struct ColumnsSet
    columns::Vector{GeneratedColumn}
    ColumnsSet() = new(GeneratedColumn[])
end
Base.iterate(set::ColumnsSet) = iterate(set.columns)
Base.iterate(set::ColumnsSet, state) = iterate(set.columns, state)

function ColGen.set_of_columns(ctx::ColGenContext)
    return ColumnsSet()
end

struct ColGenPricingResult{F,S}
    result::OptimizationState{F,S}
    columns::Vector{GeneratedColumn}
    best_red_cost::Float64
end

function ColGen.is_infeasible(pricing_res::ColGenPricingResult)
    status = getterminationstatus(pricing_res.result)
    return status == ClB.INFEASIBLE || status == ClB.INFEASIBLE_OR_UNBOUNDED
end

function ColGen.is_unbounded(pricing_res::ColGenPricingResult)
    status = getterminationstatus(pricing_res.result)
    return status == ClB.DUAL_INFEASIBLE || status == ClB.INFEASIBLE_OR_UNBOUNDED
end

ColGen.get_primal_sols(pricing_res) = pricing_res.columns
ColGen.get_dual_bound(pricing_res) = get_lp_dual_bound(pricing_res.result)

is_improving_red_cost(red_cost) = red_cost > 0
is_improving_red_cost_min_sense(red_cost) = red_cost < 0
function has_improving_red_cost(column::GeneratedColumn)
    if column.min_obj
        return is_improving_red_cost_min_sense(column.red_cost)
    end
    return is_improving_red_cost(column.red_cost)
end
# In our implementation of `push_in_set!`, we keep only columns that have improving reduced 
# cost.
function ColGen.push_in_set!(pool, column)
    # We keep only columns that improve reduced cost
    if has_improving_red_cost(column)
        push!(pool.columns, column)
    end
    return
end

function ColGen.optimize_pricing_problem!(ctx::ColGenContext, sp::Formulation{DwSp}, env, master_dual_sol)
    input = OptimizationState(sp)
    opt_state = run!(ctx.pricing_solve_alg, env, sp, input) # master & master dual sol for non robust cuts

    # Reduced cost of a column is composed of
    # (A) the cost of the subproblem variables
    # (B) the contribution of the master convexity constraints.
    # (C) the contribution of the pure master variables.

    # Master convexity constraints contribution.
    # TODO: talk with fv & Ruslan because this way to take into account convexity constraints has
    # drawbacks (numerical stability).
    lb_dual = master_dual_sol[sp.duty_data.lower_multiplicity_constr_id]
    ub_dual = master_dual_sol[sp.duty_data.upper_multiplicity_constr_id]

    # Pure master variables contribution.
    # TODO (only when stabilization is used otherwise already taken into account by master obj val)

    generated_columns = GeneratedColumn[]
    for col in get_ip_primal_sols(opt_state)
        red_cost = getvalue(col) - lb_dual - ub_dual
        push!(generated_columns, GeneratedColumn(col, red_cost))
    end

    best_red_cost = getvalue(get_ip_dual_bound(opt_state)) - lb_dual - ub_dual
    return ColGenPricingResult(opt_state, generated_columns, best_red_cost)
end

function _convexity_contrib(ctx, master_dual_sol)
    master = ColGen.get_master(ctx)
    return mapreduce(+, ColGen.get_pricing_subprobs(ctx)) do it
        _, sp = it
        lb_dual = master_dual_sol[sp.duty_data.lower_multiplicity_constr_id]
        ub_dual = master_dual_sol[sp.duty_data.upper_multiplicity_constr_id]
        lb = getcurrhs(master, sp.duty_data.lower_multiplicity_constr_id)
        ub = getcurrhs(master, sp.duty_data.upper_multiplicity_constr_id)
        return lb_dual * lb + ub_dual * ub
    end
end

function ColGen.compute_dual_bound(ctx::ColGenContext, phase, master_lp_obj_val, sp_dbs, master_dual_sol)
    sp_contrib = mapreduce(((id, val),) -> val, +, sp_dbs)
    convexity_contrib = _convexity_contrib(ctx, master_dual_sol)
    #@show master_lp_obj_val, convexity_contrib, sp_contrib
    return master_lp_obj_val - convexity_contrib + sp_contrib
end

#############################################################################
# Column generation loop
#############################################################################
function ColGen.stop_colgen_phase(ctx::ColGenContext, phase, env,  colgen_iter_output, colgen_iteration, cutsep_iteration)
    println("\e[34m -------------------- \e[00m")
    @show colgen_iter_output
    println("\e[34m -------------------- \e[00m")
    if colgen_iteration >= 10
        return true
    end
    return false
end

ColGen.before_colgen_iteration(ctx::ColGenContext, phase) = nothing
ColGen.after_colgen_iteration(ctx::ColGenContext, phase, colgen_iter_output) = nothing

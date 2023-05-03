struct BendersContext
    reform::Reformulation
    optim_sense
    restr_master_solve_alg
    restr_master_optimizer_id::Int
    nb_benders_iteration_limits::Int
    rhs_helper::RhsCalculationHelper
    second_stage_cost_var_ids::Vector{VarId}
    separation_solve_alg

    function BendersContext(reform, alg)
        return new(
            reform, 
            getobjsense(reform),
            alg.restr_master_solve_alg, 
            alg.restr_master_optimizer_id,
            alg.max_nb_iterations,
            RhsCalculationHelper(reform),
            _second_stage_cost_var_ids(reform),
            alg.separation_solve_alg
        )
    end
end

function _second_stage_cost_var_ids(reform)
    var_ids = VarId[]
    for (_, sp) in get_benders_sep_sps(reform)
        id = sp.duty_data.second_stage_cost_var
        @assert !isnothing(id)
        push!(var_ids, id)
    end
    return var_ids
end

Benders.is_minimization(ctx::BendersContext) = ctx.optim_sense == MinSense
Benders.get_reform(ctx::BendersContext) = ctx.reform
Benders.get_master(ctx::BendersContext) = getmaster(ctx.reform)
Benders.get_benders_subprobs(ctx::BendersContext) = get_benders_sep_sps(ctx.reform)
struct BendersMasterResult{F,S}
    result::OptimizationState{F,S}
end

function Benders.is_unbounded(master_res::BendersMasterResult)
    status = getterminationstatus(master_res.result)
    return status == ClB.UNBOUNDED
end

Benders.get_primal_sol(master_res::BendersMasterResult) = get_best_lp_primal_sol(master_res.result)
Benders.get_dual_sol(master_res::BendersMasterResult) = get_best_lp_dual_sol(master_res.result)

function _reset_second_stage_cost_var_inc_vals(ctx::BendersContext)
    for var_id in ctx.second_stage_cost_var_ids
        setcurincval!(Benders.get_master(ctx), var_id, 0.0)
    end
    return
end

function _update_second_stage_cost_var_inc_vals(ctx::BendersContext, master_res::BendersMasterResult)
    _reset_second_stage_cost_var_inc_vals(ctx)
    for (var_id, val) in Benders.get_primal_sol(master_res)
        setcurincval!(Benders.get_master(ctx), var_id, val)
    end
    return
end

function Benders.optimize_master_problem!(master, ctx::BendersContext, env)
    rm_input = OptimizationState(master)
    opt_state = run!(ctx.restr_master_solve_alg, env, master, rm_input, ctx.restr_master_optimizer_id)
    return BendersMasterResult(opt_state)
end

function Benders.treat_unbounded_master_problem!(master, ctx::BendersContext, env)
    mast_result = nothing
    certificate = false

    # We can derive a cut from the extreme ray
    certificates = MathProg.get_dual_infeasibility_certificate(master, getoptimizer(master, ctx.restr_master_optimizer_id))

    if length(certificates) > 0
        opt_state = OptimizationState(
            master;
            termination_status = UNBOUNDED
        )
        set_ip_primal_sol!(opt_state, first(certificates))
        set_lp_primal_sol!(opt_state, first(certificates))
        mast_result = BendersMasterResult(opt_state)
        certificate = true
    else
        # If there is no dual infeasibility certificate, we set the cost of the second stage
        # cost variable to zero and solve the master.
        # TODO: This trick can backfire on us if the optimizer finds the master unbounded 
        # and does not return any dual infeasibility certificate for several consecutive iterations.
        # It this case, we can end up with the same first level solution over and over again
        # and probably be trapped in an infinite loop.
        # We can escape the infinite loop by implementing a cut duplication checker but the
        # algorithm won't exit gracefully.
        Benders.set_second_stage_var_costs_to_zero!(ctx)
        mast_result = Benders.optimize_master_problem!(master, ctx, env)
        Benders.reset_second_stage_var_costs!(ctx)
    end
    return mast_result, certificate
end

function Benders.set_second_stage_var_costs_to_zero!(ctx::BendersContext)
    master = Coluna.MathProg.getmaster(ctx.reform)
    vars = filter(varid -> getduty(varid) <= MasterBendSecondStageCostVar, keys(getvars(master)))
    for varid in vars
        setcurcost!(master, varid, 0.0)
    end
    return
end

function Benders.reset_second_stage_var_costs!(ctx::BendersContext)
    master = Coluna.MathProg.getmaster(ctx.reform)
    vars = filter(varid -> getduty(varid) <= MasterBendSecondStageCostVar, keys(getvars(master)))
    for varid in vars
        setcurcost!(master, varid, getperencost(master, varid))
    end
    return
end

function Benders.update_sp_rhs!(ctx::BendersContext, sp, mast_primal_sol)
    spid = getuid(sp)
    peren_rhs = ctx.rhs_helper.rhs[spid]
    T = ctx.rhs_helper.T[spid]

    new_rhs = peren_rhs - T * mast_primal_sol

    for (constr_id, constr) in getconstrs(sp)
        if getduty(constr_id) <= BendSpTechnologicalConstr
            setcurrhs!(sp, constr_id, new_rhs[constr_id])
        end
    end
    return
end

function Benders.set_sp_rhs_to_zero!(ctx::BendersContext, sp, mast_primal_sol)
    spid = getuid(sp)
    T = ctx.rhs_helper.T[spid]

    new_rhs = T * mast_primal_sol

    for (constr_id, constr) in getconstrs(sp)
        if getduty(constr_id) <= BendSpTechnologicalConstr
            setcurrhs!(sp, constr_id, - new_rhs[constr_id])
        end
    end
    return
end

struct GeneratedCut
    lhs::Dict{VarId, Float64}
    rhs::Float64
    function GeneratedCut(lhs, rhs)
        return new(lhs, rhs)
    end
end

struct CutsSet
    cuts::Vector{GeneratedCut}
    CutsSet() = new(GeneratedCut[])
end
Base.iterate(set::CutsSet) = iterate(set.cuts)
Base.iterate(set::CutsSet, state) = iterate(set.cuts, state)

Benders.set_of_cuts(ctx::BendersContext) = CutsSet()

struct BendersSeparationResult{F,S}
    second_stage_estimation::Float64
    second_stage_cost::Float64
    result::OptimizationState{F,S}
    cut::GeneratedCut
end

Benders.get_primal_sol(res::BendersSeparationResult) = get_best_lp_primal_sol(res.result)

function Benders.optimize_separation_problem!(ctx::BendersContext, sp::Formulation{BendersSp}, env)
    spid = getuid(sp)
    input = OptimizationState(sp)
    opt_state = run!(ctx.separation_solve_alg, env, sp, input)

    cut_lhs = Dict{VarId, Float64}()

    # Second stage cost variable.
    cut_lhs[sp.duty_data.second_stage_cost_var] = 1.0

    # Coefficient of first stage variables.
    dual_sol = get_best_lp_dual_sol(opt_state)
    coeffs = transpose(ctx.rhs_helper.T[getuid(sp)]) * dual_sol
    for (varid, coeff) in zip(findnz(coeffs)...)
        cut_lhs[varid] = coeff
    end

    cut_rhs = transpose(dual_sol) * ctx.rhs_helper.rhs[spid]
    cut = GeneratedCut(cut_lhs, cut_rhs)

    cost = getvalue(get_lp_dual_bound(opt_state))
    second_stage_cost_var = sp.duty_data.second_stage_cost_var
    @assert !isnothing(second_stage_cost_var)
    estimated_cost = getcurincval(Benders.get_master(ctx), second_stage_cost_var)

    return BendersSeparationResult(cost, estimated_cost, opt_state, cut)
end

Benders.get_dual_sol(res::BendersSeparationResult) = get_best_lp_dual_sol(res.result)

function Benders.push_in_set!(ctx::BendersContext, set::CutsSet, sep_result::BendersSeparationResult)
    sc = Benders.is_minimization(ctx) ? 1.0 : -1.0

    # if cost of separation result > second cost variable in master result
    if sc * sep_result.second_stage_cost > sc * sep_result.second_stage_estimation
        push!(set.cuts, sep_result.cut)
        return true
    end
    return false
end

function Benders.insert_cuts!(reform, ctx::BendersContext, cuts)
    master = Benders.get_master(ctx)

    cuts_to_insert = cuts.cuts

    # We add the new cuts
    cut_ids = ConstrId[]
    for cut in cuts_to_insert
        constr = setconstr!(
            master, "Benders", MasterBendCutConstr;
            rhs = cut.rhs,
            members = cut.lhs
        )
        push!(cut_ids, getid(constr))
    end

    return cut_ids
end

struct BendersIterationOutput
    min_sense::Bool
    nb_new_cuts::Int
    infeasible_master::Bool
    infeasible_subproblem::Bool
    time_limit_reached::Bool
end

Benders.benders_iteration_output_type(ctx::BendersContext) = BendersIterationOutput

function Benders.new_iteration_output(
    ::Type{BendersIterationOutput},
    is_min_sense,
    nb_new_cuts,
    infeasible_master,
    infeasible_subproblem,
    time_limit_reached
)
    return BendersIterationOutput(
        is_min_sense,
        nb_new_cuts,
        infeasible_master,
        infeasible_subproblem,
        time_limit_reached
    )
end
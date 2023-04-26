struct BendersContext
    reform::Reformulation
    optim_sense
    restr_master_solve_alg
    restr_master_optimizer_id::Int
    nb_benders_ietartion_limits::Int
    rhs_helper::RhsCalculationHelper

    separation_solve_alg

    function BendersContext(reform, alg)
        return new(
            reform, 
            getobjsense(reform),
            alg.restr_master_solve_alg, 
            alg.restr_master_optimizer_id,
            alg.max_nb_iterations,
            RhsCalculationHelper(reform),
            alg.separation_solve_alg
        )
    end
end

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

function Benders.optimize_master_problem!(master, ctx::BendersContext, env)
    rm_input = OptimizationState(master)
    opt_state = run!(ctx.restr_master_solve_alg, env, master, rm_input, ctx.restr_master_optimizer_id)
    return BendersMasterResult(opt_state)
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
    result::OptimizationState{F,S}
    cut::GeneratedCut
end

function Benders.optimize_separation_problem!(ctx::BendersContext, sp::Formulation{BendersSp}, env)
    @show sp
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
    return BendersSeparationResult(opt_state, cut)
end

Benders.get_dual_sol(res::BendersSeparationResult) = get_best_lp_dual_sol(res.result)

function Benders.push_in_set!(ctx::BendersContext, set::CutsSet, sep_result::BendersSeparationResult)
    @show sep_result.cut
    push!(set.cuts, sep_result.cut)
    return true
end

function Benders.insert_cuts!(reform, ctx, cuts)
    master = Benders.get_master(ctx)
    @show cuts

    cuts_to_insert = cuts.cuts  #GeneratedCut[]

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
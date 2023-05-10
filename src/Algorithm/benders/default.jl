struct BendersContext <: Benders.AbstractBendersContext
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

_deactivate_art_vars(sp) = deactivate!(sp, vcid -> isanArtificialDuty(getduty(vcid)))
_activate_art_vars(sp) = activate!(sp, vcid -> isanArtificialDuty(getduty(vcid)))

function Benders.setup_reformulation!(reform::Reformulation, env)
    for (_, sp) in get_benders_sep_sps(reform)
        _deactivate_art_vars(sp)
    end
    return
end

struct BendersMasterResult{F,S}
    ip_solver::Bool
    result::OptimizationState{F,S}
    infeasible::Bool
    unbounded::Bool
    certificate::Bool
end

Benders.is_unbounded(master_res::BendersMasterResult) = master_res.unbounded
Benders.is_infeasible(master_res::BendersMasterResult) = master_res.infeasible
Benders.is_certificate(master_res::BendersMasterResult) = master_res.certificate

function Benders.get_primal_sol(master_res::BendersMasterResult)
    if master_res.ip_solver
        return get_best_ip_primal_sol(master_res.result)
    end
    return get_best_lp_primal_sol(master_res.result)
end

Benders.get_dual_sol(master_res::BendersMasterResult) = get_best_lp_dual_sol(master_res.result)
Benders.get_obj_val(master_res::BendersMasterResult) = getvalue(Benders.get_primal_sol(master_res))

function _reset_second_stage_cost_var_inc_vals(ctx::BendersContext)
    for var_id in ctx.second_stage_cost_var_ids
        setcurincval!(Benders.get_master(ctx), var_id, 0.0)
    end
    return
end

function _update_second_stage_cost_var_inc_vals(ctx::BendersContext, master_res::BendersMasterResult)
    isnothing(Benders.get_primal_sol(master_res)) && return
    _reset_second_stage_cost_var_inc_vals(ctx)
    for (var_id, val) in Benders.get_primal_sol(master_res)
        setcurincval!(Benders.get_master(ctx), var_id, val)
    end
    return
end

function Benders.optimize_master_problem!(master, ctx::BendersContext, env)
    rm_input = OptimizationState(master)
    opt_state = run!(ctx.restr_master_solve_alg, env, master, rm_input, ctx.restr_master_optimizer_id)
    ip_solver = typeof(ctx.restr_master_solve_alg) <: SolveIpForm
    unbounded = getterminationstatus(opt_state) == UNBOUNDED
    infeasible = getterminationstatus(opt_state) == INFEASIBLE
    master_res = BendersMasterResult(ip_solver, opt_state, infeasible, unbounded, false)
    _update_second_stage_cost_var_inc_vals(ctx, master_res)
    return master_res
end

function Benders.treat_unbounded_master_problem!(master, ctx::BendersContext, env)
    mast_result = nothing
    ip_solver = typeof(ctx.restr_master_solve_alg) <: SolveIpForm

    # In the unbounded case, to get a dual infeasibility certificate, we need to relax the 
    # integrality and solve the master again. (at least with GLPK & the current implementation of SolveIpForm)
    if ip_solver
        relax_integrality!(master)
        rm_input = OptimizationState(master)
        opt_state = run!(SolveLpForm(get_dual_solution = true), env, master, rm_input, ctx.restr_master_optimizer_id)
        enforce_integrality!(master)
    end

    # We can derive a cut from the extreme ray
    certificates = MathProg.get_dual_infeasibility_certificate(master, getoptimizer(master, ctx.restr_master_optimizer_id))

    if length(certificates) > 0
        opt_state = OptimizationState(master; )
        set_ip_primal_sol!(opt_state, first(certificates))
        set_lp_primal_sol!(opt_state, first(certificates))
        mast_result = BendersMasterResult(ip_solver, opt_state, false, false, true)
        _update_second_stage_cost_var_inc_vals(ctx, mast_result)
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
    return mast_result
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
    min_sense::Bool
    lhs::Dict{VarId, Float64}
    rhs::Float64
    function GeneratedCut(min_sense, lhs, rhs)
        return new(min_sense, lhs, rhs)
    end
end

struct CutsSet
    cuts::Vector{GeneratedCut}
    CutsSet() = new(GeneratedCut[])
end
Base.iterate(set::CutsSet) = iterate(set.cuts)
Base.iterate(set::CutsSet, state) = iterate(set.cuts, state)

Benders.set_of_cuts(::BendersContext) = CutsSet()

struct SepSolSet
    sols::Vector{PrimalSolution}
    SepSolSet() = new(PrimalSolution[])
end
Benders.set_of_sep_sols(::BendersContext) = SepSolSet()

struct BendersSeparationResult{F,S}
    second_stage_estimation::Float64
    second_stage_cost::Union{Nothing,Float64}
    result::OptimizationState{F,S}
    infeasible::Bool
    unbounded::Bool
    certificate::Union{Nothing,DualSolution}
    cut::Union{Nothing,GeneratedCut}
    unbounded_master::Bool
end

Benders.get_primal_sol(res::BendersSeparationResult) = get_best_lp_primal_sol(res.result)
Benders.is_infeasible(res::BendersSeparationResult) = res.infeasible
Benders.is_unbounded(res::BendersSeparationResult) = res.unbounded

# This is a kind of phase 1 for the separation problem when it is infeasible.
function _optimize_feasibility_separation_problem!(ctx, sp::Formulation{BendersSp}, env)
    for (varid, _) in getvars(sp)
        if !isanArtificialDuty(getduty(varid))
            setcurcost!(sp, varid, 0.0)
        end
    end
    _activate_art_vars(sp)

    input = OptimizationState(sp)
    opt_state = run!(ctx.separation_solve_alg, env, sp, input)

    for (varid, _) in getvars(sp)
        if !isanArtificialDuty(getduty(varid))
            setcurcost!(sp, varid, getperencost(sp, varid))
        end
    end
    _deactivate_art_vars(sp)
    return opt_state
end

function Benders.optimize_separation_problem!(ctx::BendersContext, sp::Formulation{BendersSp}, env, unbounded_master)
    spid = getuid(sp)

    second_stage_cost_var = sp.duty_data.second_stage_cost_var
    @assert !isnothing(second_stage_cost_var)
    estimated_cost = getcurincval(Benders.get_master(ctx), second_stage_cost_var)

    input = OptimizationState(sp)
    opt_state = run!(ctx.separation_solve_alg, env, sp, input)

    if getterminationstatus(opt_state) == UNBOUNDED
        return BendersSeparationResult(estimated_cost, nothing, opt_state, true, false, nothing, nothing, unbounded_master)
    end

    feasibility_cut = false
    infeasible = getterminationstatus(opt_state) == INFEASIBLE
    if infeasible
        feasibility_cut = true
        opt_state = _optimize_feasibility_separation_problem!(ctx, sp, env)
    end

    infeasible = getterminationstatus(opt_state) == INFEASIBLE
    if infeasible
        return BendersSeparationResult(estimated_cost, nothing, opt_state, false, true, nothing, nothing, unbounded_master)
    end

    dual_sol = get_best_lp_dual_sol(opt_state)
    cost = getvalue(dual_sol)
    min_sense = Benders.is_minimization(ctx)
    sc = min_sense ? 1.0 : - 1.0
    if sc * cost < sc * estimated_cost
        # Unbounded error if in Master unbounded case
        if !feasibility_cut && unbounded_master
          return BendersSeparationResult(estimated_cost, nothing, opt_state, false, true, nothing, nothing, true)
        end
        # Optimal solution in the othercase
    end

    cut_lhs = Dict{VarId, Float64}()

    coeffs = transpose(ctx.rhs_helper.T[getuid(sp)]) * dual_sol
    for (varid, coeff) in zip(findnz(coeffs)...)
        cut_lhs[varid] = coeff
    end

    if feasibility_cut
        cut_lhs[sp.duty_data.second_stage_cost_var] = 0.0
    else
        cut_lhs[sp.duty_data.second_stage_cost_var] = 1.0
    end

    bounds_contrib_to_rhs = 0.0
    for (varid, (val, active_bound)) in get_var_redcosts(dual_sol)
        if active_bound == MathProg.LOWER || active_bound == MathProg.LOWER_AND_UPPER
            bounds_contrib_to_rhs += val * getcurlb(sp, varid)
        elseif active_bound == MathProg.UPPER
            bounds_contrib_to_rhs += val * getcurub(sp, varid)
        end
    end

    cut_rhs = transpose(dual_sol) * ctx.rhs_helper.rhs[spid] + bounds_contrib_to_rhs
    cut = GeneratedCut(min_sense, cut_lhs, cut_rhs)

    return BendersSeparationResult(estimated_cost, cost, opt_state, false, false, dual_sol, cut, unbounded_master)
end

function Benders.get_dual_sol(res::BendersSeparationResult)
    if res.infeasible
        return res.certificate
    end
    return get_best_lp_dual_sol(res.result)
end

function Benders.push_in_set!(ctx::BendersContext, set::CutsSet, sep_result::BendersSeparationResult)
    sc = Benders.is_minimization(ctx) ? 1.0 : -1.0
    eq = abs(sep_result.second_stage_cost - sep_result.second_stage_estimation) < 1e-5
    gt = sc * sep_result.second_stage_cost > sc * sep_result.second_stage_estimation

    # if cost of separation result > second cost variable in master result
    if !eq && gt
        push!(set.cuts, sep_result.cut)
        return true
    end
    return false
end

function Benders.push_in_set!(ctx::BendersContext, set::SepSolSet, sep_result::BendersSeparationResult)
    push!(set.sols, Benders.get_primal_sol(sep_result))
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
            members = cut.lhs,
            sense = cut.min_sense ? Greater : Less,
        )
        push!(cut_ids, getid(constr))
    end
    return cut_ids
end

function Benders.build_primal_solution(context::BendersContext, mast_primal_sol, sep_sp_sols)
    # Keep BendSpSepVar and MasterPureVar
    var_ids = VarId[]
    var_vals = Float64[]

    for (varid, val) in mast_primal_sol
        if getduty(varid) <= MasterPureVar
            push!(var_ids, varid)
            push!(var_vals, val)
        end
    end

    for sp_sol in sep_sp_sols.sols
        for (varid, val) in sp_sol
            @show sp_sol
            #if getduty(varid) <= BendSpSepVar
                push!(var_ids, varid)
                push!(var_vals, val)
            #end
        end
    end

    return Coluna.PrimalSolution(
        Benders.get_master(context), # TODO: second stage vars does not belong to the master
        var_ids,
        var_vals,
        getvalue(mast_primal_sol),
        FEASIBLE_SOL
    )
end

struct BendersIterationOutput <: Benders.AbstractBendersIterationOutput
    min_sense::Bool
    nb_new_cuts::Int
    ip_primal_sol::Union{Nothing,PrimalSolution}
    infeasible::Bool
    time_limit_reached::Bool
    master::Union{Nothing,Float64}
end

Benders.benders_iteration_output_type(ctx::BendersContext) = BendersIterationOutput

function Benders.new_iteration_output(
    ::Type{BendersIterationOutput},
    is_min_sense,
    nb_new_cuts,
    ip_primal_sol,
    infeasible,
    time_limit_reached,
    master_value
)
    if !isnothing(ip_primal_sol) && contains(ip_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
        infeasible_subproblem = true
    end
    return BendersIterationOutput(
        is_min_sense,
        nb_new_cuts,
        ip_primal_sol,
        infeasible,
        time_limit_reached,
        master_value
    )
end

struct BendersOutput <: Benders.AbstractBendersOutput
    infeasible::Bool
    time_limit_reached::Bool
    mlp::Union{Nothing, Float64}
end

Benders.benders_output_type(::BendersContext) = BendersOutput

function Benders.new_output(
    ::Type{BendersOutput},
    benders_iter_output::BendersIterationOutput
)
    return BendersOutput(
        benders_iter_output.infeasible,
        benders_iter_output.time_limit_reached,
        benders_iter_output.master
    )
end

Benders.stop_benders(::BendersContext, ::Nothing, benders_iteration) = false
function Benders.stop_benders(ctx::BendersContext, benders_iteration_output::BendersIterationOutput, benders_iteration)
    return benders_iteration_output.infeasible ||
        benders_iteration_output.time_limit_reached ||
        benders_iteration_output.nb_new_cuts <= 0 ||
        ctx.nb_benders_iteration_limits <= benders_iteration
end

function Benders.after_benders_iteration(::BendersContext, phase, env, iteration, benders_iter_output)
    return
end
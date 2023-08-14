"""
    BendersContext(reformulation, algo_params) -> BendersContext

Default implementation of the Benders algorithm.
"""
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


"""
Output of the default implementation of the `Benders.optimize_master_problem!` method.

It contains:
- `ip_solver`: `true` if the master problem is solved with a MIP solver and involves integral variables, `false` otherwise.
- `result`: the result of the master problem optimization stored in an `OptimizationState` object.
- `infeasible`: `true` if the master at the current iteration is infeasible; `false` otherwise.
- `unbounded`: `true` if the master at the current iteration is unbounded; `false` otherwise.
- `certificate`: `true` if the master at the current iteration is unbounded and if the current result is a dual infeasibility certificate, `false` otherwise.
"""
struct BendersMasterResult{F}
    ip_solver::Bool
    result::OptimizationState{F}
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

function Benders.treat_unbounded_master_problem_case!(master, ctx::BendersContext, env)
    mast_result = nothing
    ip_solver = typeof(ctx.restr_master_solve_alg) <: SolveIpForm

    # In the unbounded case, to get a dual infeasibility certificate, we need to relax the 
    # integrality and solve the master again. (at least with GLPK & the current implementation of SolveIpForm)
    if ip_solver
        relax_integrality!(master)
        rm_input = OptimizationState(master)
        opt_state = run!(SolveLpForm(get_dual_sol = true), env, master, rm_input, ctx.restr_master_optimizer_id)
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
        set_second_stage_var_costs_to_zero!(ctx)
        mast_result = Benders.optimize_master_problem!(master, ctx, env)
        reset_second_stage_var_costs!(ctx)
    end
    return mast_result
end

function set_second_stage_var_costs_to_zero!(ctx::BendersContext)
    master = Coluna.MathProg.getmaster(ctx.reform)
    vars = filter(varid -> getduty(varid) <= MasterBendSecondStageCostVar, keys(getvars(master)))
    for varid in vars
        setcurcost!(master, varid, 0.0)
    end
    return
end

function reset_second_stage_var_costs!(ctx::BendersContext)
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
        else
            setcurrhs!(sp, constr_id, getperenrhs(sp, constr_id))
        end
    end

    for (var_id, var) in getvars(sp)
        setcurlb!(sp, var_id, getperenlb(sp, var_id))
        setcurub!(sp, var_id, getperenub(sp, var_id))
    end
    return
end

function Benders.setup_separation_for_unbounded_master_case!(ctx::BendersContext, sp, mast_primal_sol)
    spid = getuid(sp)
    T = ctx.rhs_helper.T[spid]

    new_rhs = T * mast_primal_sol

    for (constr_id, constr) in getconstrs(sp)
        if getduty(constr_id) <= BendSpTechnologicalConstr
            setcurrhs!(sp, constr_id, - new_rhs[constr_id])
        else
            setcurrhs!(sp, constr_id, 0.0)
        end
    end
    
    for (var_id, var) in getvars(sp)
        if !(getduty(var_id) <= BendSpSecondStageArtVar)
            if getobjsense(sp) == MinSense
                setcurlb!(sp, var_id, 0.0)
                setcurub!(sp, var_id, Inf)
            else
                setcurlb!(sp, var_id, 0.0)
                setcurub!(sp, var_id, Inf)
            end
        end
    end
    return
end

"""
Solution to the separation problem together with its corresponding benders cut.

It contains:
- `min_sense`: `true` if it's a minimization problem; `false` otherwise.
- `lhs`: the left-hand side of the cut.
- `rhs`: the right-hand side of the cut.
- `dual_sol`: an optimal dual solution to the separation problem.
"""
struct GeneratedCut{F}
    min_sense::Bool
    lhs::Dict{VarId, Float64}
    rhs::Float64
    dual_sol::DualSolution{F}
end

"""
Stores a collection of cuts.

It contains `cuts` a vector of `GeneratedCut` objects.
"""
struct CutsSet
    cuts::Vector{GeneratedCut}
    CutsSet() = new(GeneratedCut[])
end
Base.iterate(set::CutsSet) = iterate(set.cuts)
Base.iterate(set::CutsSet, state) = iterate(set.cuts, state)

Benders.set_of_cuts(::BendersContext) = CutsSet()

"""
Primal solutions to the separation problems optimized at the current iteration.
This is used to build a primal solution.

It contains `sols` a vector of primal solutions. 
"""
struct SepSolSet{F}
    sols::Vector{MathProg.PrimalSolution{F}}
end
SepSolSet{F}() where {F} = SepSolSet{F}(MathProg.PrimalSolution{F}[])
Benders.set_of_sep_sols(::BendersContext) = SepSolSet{MathProg.Formulation{MathProg.BendersSp}}()

"""
Output of the default implementation of the `Benders.optimize_separation_problem!` and
`Benders.treat_infeasible_separation_problem_case!` methods.

It contains:
- `second_stage_estimation_in_master`: the value of the second stage cost variable in the solution to the master problem.
- `second_stage_cost`: the value of the second stage cost variable in the solution to the separation problem.
- `lp_primal_sol`: the primal solution to the separation problem.
- `infeasible`: `true` if the current separation problem is infeasible; `false` otherwise.
- `unbounded`: `true` if the current separation problem is unbounded; `false` otherwise.
- `cut`: the cut generated by the separation problem.
- `infeasible_treatment`: `true` if this object is an output of the `Benders.treat_infeasible_separation_problem_case!` method; `false` otherwise.
- `unbounded_master`: `true` if the separation subproblem has the form of Lemma 2 to separate a cut to truncate an unbounded ray of the restricted master problem; `false` otherwise.
"""
struct BendersSeparationResult{F}
    second_stage_estimation_in_master::Float64
    second_stage_cost::Union{Nothing,Float64}
    lp_primal_sol::Union{Nothing,MathProg.PrimalSolution{F}}
    infeasible::Bool
    unbounded::Bool
    cut::Union{Nothing,GeneratedCut{F}}
    infeasible_treatment::Bool
    unbounded_master::Bool
end
 
Benders.get_obj_val(res::BendersSeparationResult) = res.second_stage_cost
Benders.get_primal_sol(res::BendersSeparationResult) = res.lp_primal_sol
Benders.is_infeasible(res::BendersSeparationResult) = res.infeasible
Benders.is_unbounded(res::BendersSeparationResult) = res.unbounded
Benders.get_dual_sol(res::BendersSeparationResult) = res.cut.dual_sol

## original MIP:
## min cx + dy s.t.
##  Ax >= b 
##  Tx + Qy >= r
##  x, y >= 0, x ∈ Z^n

## master:
## min cx + η
##  Ax >= B
##  < benders cuts >

## SP: ## depends on master attributes (e.g. unbounded), x* fixed
## min  dy
##  Tx* + Qy >= r
##  y >= 0

## π: dual sol
## η: contribution to the objective of the second-level variables
## feasibility cut: πTx >= πr
## optimality cut: η + πTx >= πr

## Depending on the nature of the cut (feasibility of optimality cut), the left hand side of the cut is equal to either 0.η + πT.x or to 1.η + πT.x. In both cases we have to compute the coefficients behind x variables using the matrix T. The coefficients are stored in a dictionnary cut_lhs that matches each var id with its coefficient in the cut. 
## second_stage_cost_var: id of the variable η representing the cost of the second stage variables
## T: the matrix which stores the coefficients of x variables in the current subproblem
## dual sol: the dual solution π of the current subproblem
## feasibility_cut: boolean set to true if the current cut is a feasibility cut, false otherwise 
function _compute_cut_lhs(ctx, sp, dual_sol, feasibility_cut)
    cut_lhs = Dict{VarId, Float64}()
    coeffs = transpose(ctx.rhs_helper.T[getuid(sp)]) * dual_sol ## πTx
    for (varid, coeff) in zip(findnz(coeffs)...)
        cut_lhs[varid] = coeff
    end

    if feasibility_cut
        cut_lhs[sp.duty_data.second_stage_cost_var] = 0.0 ## πTx (feasibility cut)
    else
        cut_lhs[sp.duty_data.second_stage_cost_var] = 1.0 ## η + πTx (optimality cut)
    end
    return cut_lhs
end

## For both feasibility and optimality cuts, the right-hand side is given by πr with π the dual solution of the current sp and r the right-hand side of the sp linear constraints. However, in the implementation, the bounding constraints are considered separately from the other linear constraints. Thus, we add to πr the contribution of the bounding constraints to the right-hand side of our cut. 
function _compute_cut_rhs_contrib(ctx, sp, dual_sol)
    spid = getuid(sp)
    bounds_contrib_to_rhs = 0.0 ##init bounding constraints contribution to the right-hand side of the cut
    for (varid, (val, active_bound)) in get_var_redcosts(dual_sol) ##compute bounding constraints contribution ; val is the dual value of the bounding constraint, active_bound indicates whoever the bound is a LOWER or a UPPER bound
        if active_bound == MathProg.LOWER 
            bounds_contrib_to_rhs += val * getperenlb(sp, varid)
        elseif active_bound == MathProg.UPPER
            bounds_contrib_to_rhs += val * getperenub(sp, varid)
        end
    end

    cut_rhs = transpose(dual_sol) * ctx.rhs_helper.rhs[spid] + bounds_contrib_to_rhs ## πr + bounding constraints contrib 
    return cut_rhs
end


function Benders.optimize_separation_problem!(ctx::BendersContext, sp::Formulation{BendersSp}, env, unbounded_master)
    spid = getuid(sp)

    second_stage_cost_var = sp.duty_data.second_stage_cost_var
    @assert !isnothing(second_stage_cost_var)
    estimated_cost = getcurincval(Benders.get_master(ctx), second_stage_cost_var)

    input = OptimizationState(sp)
    opt_state = run!(ctx.separation_solve_alg, env, sp, input)

    if getterminationstatus(opt_state) == UNBOUNDED
        return BendersSeparationResult{Formulation{BendersSp}}(estimated_cost, nothing, get_best_lp_primal_sol(opt_state), false, true, nothing, false, unbounded_master)
    end

    if getterminationstatus(opt_state) == INFEASIBLE ## we then enter treat_infeasible_separation_problem_case! (phase 1)
        return BendersSeparationResult{Formulation{BendersSp}}(estimated_cost, nothing, get_best_lp_primal_sol(opt_state), true, false, nothing, false, unbounded_master)
    end
    ## create and add cuts to the result 
    dual_sol = get_best_lp_dual_sol(opt_state)
    cost = getvalue(dual_sol)
    min_sense = Benders.is_minimization(ctx)
    cut_lhs = _compute_cut_lhs(ctx, sp, dual_sol, false)
    cut_rhs = _compute_cut_rhs_contrib(ctx, sp, dual_sol)

    cut = GeneratedCut(min_sense, cut_lhs, cut_rhs, dual_sol)
    return BendersSeparationResult(estimated_cost, cost, get_best_lp_primal_sol(opt_state), false, false, cut, false, unbounded_master)
end

function Benders.master_is_unbounded(ctx::BendersContext, second_stage_cost, unbounded_master_case)
    if !unbounded_master_case
        return false
    end

    estimated_cost = 0
    for (spid, sp) in Benders.get_benders_subprobs(ctx)
        second_stage_cost_var = sp.duty_data.second_stage_cost_var
        estimated_cost += getcurincval(Benders.get_master(ctx), second_stage_cost_var) ## compute cost η considering ALL subproblems
    end

    min_sense = Benders.is_minimization(ctx)
    sc = min_sense ? 1.0 : - 1.0
    return sc * second_stage_cost < sc * estimated_cost + 1e-5
end

## it is a phase 1: add artificial variables in order to find a feasible solution
function Benders.treat_infeasible_separation_problem_case!(ctx::BendersContext, sp::Formulation{BendersSp}, env, unbounded_master_case)
    second_stage_cost_var = sp.duty_data.second_stage_cost_var
    @assert !isnothing(second_stage_cost_var)
    estimated_cost = getcurincval(Benders.get_master(ctx), second_stage_cost_var)

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

    if getterminationstatus(opt_state) == INFEASIBLE
        error("A") # should not happen
    end

    dual_sol = get_best_lp_dual_sol(opt_state)
    cost = getvalue(dual_sol)
    min_sense = Benders.is_minimization(ctx)
    sc = min_sense ? 1.0 : - 1.0

    if sc * cost <= 0
        error("B") # should not happen
    end

    cut_lhs = _compute_cut_lhs(ctx, sp, dual_sol, true)
    cut_rhs = _compute_cut_rhs_contrib(ctx, sp, dual_sol)
    cut = GeneratedCut(min_sense, cut_lhs, cut_rhs, dual_sol)
    return BendersSeparationResult(estimated_cost, cost, get_best_lp_primal_sol(opt_state), false, false, cut, true, unbounded_master_case)
end

function Benders.push_in_set!(ctx::BendersContext, set::CutsSet, sep_result::BendersSeparationResult)
    if isnothing(sep_result.cut)
        return false
    end
    
    sc = Benders.is_minimization(ctx) ? 1.0 : -1.0
    eq = abs(sep_result.second_stage_cost - sep_result.second_stage_estimation_in_master) < 1e-5
    gt = sc * sep_result.second_stage_cost + 1e-5 > sc * sep_result.second_stage_estimation_in_master

    # if cost of separation result > second cost variable in master result
    if !eq && gt || sep_result.infeasible_treatment
        push!(set.cuts, sep_result.cut)
        return true
    end
    return false
end

function Benders.push_in_set!(ctx::BendersContext, set::SepSolSet, sep_result::BendersSeparationResult)
    push!(set.sols, Benders.get_primal_sol(sep_result))
end

struct CutAlreadyInsertedBendersWarning
    cut_in_master::Bool
    cut_is_active::Bool
    cut_id::ConstrId
    master::Formulation{BendersMaster}
    subproblem::Formulation{BendersSp}
end

function Base.show(io::IO, err::CutAlreadyInsertedBendersWarning)
    msg = """
    Unexpected constraint state during cut insertion.
    ======
    Cut id: $(err.cut_id).
    The cut is in the master ? $(err.cut_in_master).
    The cut is active ? $(err.cut_is_active).
    ======
    """
    println(io, msg)
end

function Benders.insert_cuts!(reform, ctx::BendersContext, cuts)
    master = Benders.get_master(ctx)

    cuts_to_insert = GeneratedCut[]
    cut_ids_to_activate = Set{ConstrId}()

    for cut in cuts.cuts
        dual_sol = cut.dual_sol
        spform = getmodel(dual_sol)
        pool = get_dual_sol_pool(spform)
        cut_id = MathProg.get_from_pool(pool, dual_sol)
        if !isnothing(cut_id)
            if haskey(master, cut_id) && !iscuractive(master, cut_id)
                push!(cut_ids_to_activate, cut_id)
            else
                in_master = haskey(master, cut_id)
                is_active = iscuractive(master, cut_id)
                warning = CutAlreadyInsertedBendersWarning(
                    in_master, is_active, cut_id, master, spform
                )
                throw(warning) # TODO: parameter
            end
        else
            push!(cuts_to_insert, cut)
        end
    end

    nb_added_cuts = 0
    nb_reactivated_cut = 0

    # Then, we add the new cuts (i.e. not in the pool)
    cut_ids = ConstrId[]
    for cut in cuts_to_insert
        constr = setconstr!(
            master, "Benders", MasterBendCutConstr;
            rhs = cut.rhs,
            members = cut.lhs,
            sense = cut.min_sense ? Greater : Less,
        )
        push!(cut_ids, getid(constr))


        dual_sol = cut.dual_sol
        spform = getmodel(dual_sol)
        pool = get_dual_sol_pool(spform)

        # if store_in_sp_pool
        cut_id = ConstrId(getid(constr); duty = MasterBendCutConstr)
        MathProg.push_in_pool!(pool, dual_sol, cut_id, getvalue(dual_sol))
        # end

        nb_added_cuts += 1
    end

    # Finally, we reactivate the cuts that were already in the pool
    for cut_id in cut_ids_to_activate
        activate!(master, cut_id)
        push!(cut_ids, cut_id)
        nb_reactivated_cut += 1
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

"""
Output of the default implementation of an iteration of the Benders algorithm.

It contains:
- `min_sense`: the original problem is a minimization problem
- `nb_new_cuts`: the number of new cuts added to the master problem
- `ip_primal_sol`: the primal solution to the original problem found during this iteration
- `infeasible`: the original problem is infeasible
- `time_limit_reached`: the time limit was reached
- `master`: the solution value to the master problem
"""
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

"""
Output of the default implementation of the Benders algorithm.

It contains:
- `infeasible`: the original problem is infeasible
- `time_limit_reached`: the time limit was reached
- `mlp`: the final bound obtained with the Benders cut algorithm
- `ip_primal_sol`: the best primal solution to the original problem found by the Benders cut algorithm
"""
struct BendersOutput <: Benders.AbstractBendersOutput
    infeasible::Bool
    time_limit_reached::Bool
    mlp::Union{Nothing, Float64}
    ip_primal_sol::Union{Nothing,PrimalSolution}
end

Benders.benders_output_type(::BendersContext) = BendersOutput

function Benders.new_output(
    ::Type{BendersOutput},
    benders_iter_output::BendersIterationOutput
)
    return BendersOutput(
        benders_iter_output.infeasible,
        benders_iter_output.time_limit_reached,
        benders_iter_output.master,
        benders_iter_output.ip_primal_sol
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
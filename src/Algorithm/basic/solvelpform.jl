"""
    Coluna.Algorithm.SolveLpForm(
        get_dual_solution = false,
        relax_integrality = false,
        get_dual_bound = false,
        silent = true
    )

Solve a linear program stored in a formulation using its first optimizer.
This algorithm works only if the optimizer is interfaced with MathOptInterface.

You can define the optimizer using the `default_optimizer` attribute of Coluna or
with the method `specify!` from BlockDecomposition

Parameters:
- `get_dual_solution`: retrieve the dual solution and store it in the ouput if equals `true`
- `relax_integrality`: relax integer variables of the formulation before optimization if equals `true`
- `get_dual_bound`: store the dual objective value in the output if equals `true`
- `silent`: set `MOI.Silent()` to its value

Undocumented parameters are alpha.
"""
@with_kw struct SolveLpForm <: AbstractOptimizationAlgorithm 
    update_ip_primal_solution = false
    consider_partial_solution = false
    get_dual_solution = false
    relax_integrality = false
    get_dual_bound = false
    silent = true
    log_level = 0
end

# SolveLpForm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_units_usage(
    algo::SolveLpForm, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use units in the read only mode, as relaxing integrality
    # is reverted before the end of the algorithm, 
    # so the state of the formulation remains the same 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[] 
    push!(units_usage, (form, StaticVarConstrUnit, READ_ONLY))
    if Duty <: MathProg.AbstractMasterDuty
        push!(units_usage, (form, MasterColumnsUnit, READ_ONLY))
        push!(units_usage, (form, MasterBranchConstrsUnit, READ_ONLY))
        push!(units_usage, (form, MasterCutsUnit, READ_ONLY))
    end
    if algo.consider_partial_solution
        push!(units_usage, (form, PartialSolutionUnit, READ_ONLY))
    end
    return units_usage
end

function termination_status!(result::OptimizationState, optimizer::MoiOptimizer)
    terminationstatus = MOI.get(getinner(optimizer), MOI.TerminationStatus())
    if terminationstatus != MOI.INFEASIBLE &&
            terminationstatus != MOI.DUAL_INFEASIBLE &&
            terminationstatus != MOI.INFEASIBLE_OR_UNBOUNDED &&
            terminationstatus != MOI.OPTIMIZE_NOT_CALLED &&
            terminationstatus != MOI.INVALID_MODEL &&
            terminationstatus != MOI.TIME_LIMIT

        setterminationstatus!(result, convert_status(terminationstatus))

        if MOI.get(getinner(optimizer), MOI.ResultCount()) <= 0
            msg = """
            Termination status = $(terminationstatus) but no results.
            Please, open an issue at https://github.com/atoptima/Coluna.jl/issues
            """
            error(msg)
        end
    else
        @warn "Solver has no result to show."
        setterminationstatus!(result, INFEASIBLE)
    end
    return
end

function optimize_with_moi!(optimizer::MoiOptimizer, form::Formulation, result::OptimizationState)
    sync_solver!(optimizer, form)
    println(optimizer.inner)
    nbvars = MOI.get(optimizer.inner, MOI.NumberOfVariables())
    if nbvars <= 0
        @warn "No variable in the formulation."
    end
    MOI.optimize!(getinner(optimizer))
    termination_status!(result, optimizer)
    return
end

function optimize_lp_form!(::SolveLpForm, optimizer, ::Formulation, ::OptimizationState) # fallback
    error("Cannot optimize LP formulation with optimizer of type ", typeof(optimizer), ".")
end

function optimize_lp_form!(
    algo::SolveLpForm, optimizer::MoiOptimizer, form::Formulation, result::OptimizationState
)
    MOI.set(optimizer.inner, MOI.Silent(), algo.silent)
    optimize_with_moi!(optimizer, form, result)
    return
end

function run!(
    algo::SolveLpForm, ::Env, form::Formulation, input::OptimizationInput, 
    optimizer_id::Int = 1
)::OptimizationOutput
    result = OptimizationState(form)

    TO.@timeit Coluna._to "SolveLpForm" begin

    if algo.relax_integrality
        relax_integrality!(form)
    end

    partial_sol = nothing
    partial_sol_val = 0.0
    if algo.consider_partial_solution
        partsolunit = getstorageunit(form, PartialSolutionUnit)
        partial_sol = get_primal_solution(partsolunit, form)
        partial_sol_val = getvalue(partial_sol)
    end

    optimizer = getoptimizer(form, optimizer_id)
    optimize_lp_form!(algo, optimizer, form, result)
    primal_sols = get_primal_solutions(form, optimizer)

    coeff = getobjsense(form) == MinSense ? 1.0 : -1.0

    if algo.get_dual_solution
        dual_sols = get_dual_solutions(form, optimizer)
        if length(dual_sols) > 0
            lp_dual_sol_pos = argmax(coeff * getvalue.(dual_sols))
            lp_dual_sol = dual_sols[lp_dual_sol_pos]
            set_lp_dual_sol!(result, lp_dual_sol)
            if algo.get_dual_bound
                db = DualBound(form, getvalue(lp_dual_sol) + partial_sol_val)
                set_lp_dual_bound!(result, db)
            end
        end
    end

    if length(primal_sols) > 0
        lp_primal_sol_pos = argmin(coeff * getvalue.(primal_sols))
        lp_primal_sol = primal_sols[lp_primal_sol_pos]
        add_lp_primal_sol!(result, lp_primal_sol)
        pb = PrimalBound(form, getvalue(lp_primal_sol) + partial_sol_val)
        set_lp_primal_bound!(result, pb)
        if algo.update_ip_primal_solution && isinteger(lp_primal_sol) && 
            !contains(lp_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
            if partial_sol !== nothing
                add_ip_primal_sol!(result, cat(lp_primal_sol, partial_sol))
            else
                add_ip_primal_sol!(result, lp_primal_sol)
            end
        end
    end
    end # @timeit
    return OptimizationOutput(result)
end

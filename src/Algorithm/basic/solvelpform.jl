"""
    Coluna.Algorithm.SolveLpForm(
        get_ip_primal_sol = false,
        get_dual_sol = false,
        relax_integrality = false,
        get_dual_bound = false,
        silent = true
    )

Solve a linear program stored in a formulation using its first optimizer.
This algorithm works only if the optimizer is interfaced with MathOptInterface.

You can define the optimizer using the `default_optimizer` attribute of Coluna or
with the method `specify!` from BlockDecomposition

Parameters:
- `get_ip_primal_sol`: update the primal solution of the formulation if equals `true`
- `get_dual_sol`: retrieve the dual solution and store it in the ouput if equals `true`
- `relax_integrality`: relax integer variables of the formulation before optimization if equals `true`
- `get_dual_bound`: store the dual objective value in the output if equals `true`
- `silent`: set `MOI.Silent()` to its value

Undocumented parameters are alpha.
"""
struct SolveLpForm <: AbstractOptimizationAlgorithm
    get_ip_primal_sol::Bool
    get_dual_sol::Bool
    relax_integrality::Bool
    get_dual_bound::Bool
    silent::Bool
    SolveLpForm(;
        get_ip_primal_sol = false,
        get_dual_sol = false,
        relax_integrality = false,
        get_dual_bound = false,
        silent = true
    ) = new(get_ip_primal_sol, get_dual_sol, relax_integrality, get_dual_bound, silent)
end

# SolveLpForm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_units_usage(
    algo::SolveLpForm, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use units in the read only mode, as relaxing integrality
    # is reverted before the end of the algorithm, 
    # so the state of the formulation remains the same 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[] 
    #push!(units_usage, (form, StaticVarConstrUnit, READ_ONLY))
    if Duty <: MathProg.AbstractMasterDuty
        push!(units_usage, (form, MasterColumnsUnit, READ_ONLY))
        push!(units_usage, (form, MasterBranchConstrsUnit, READ_ONLY))
        push!(units_usage, (form, MasterCutsUnit, READ_ONLY))
    end
    return units_usage
end

function optimize_lp_form!(::SolveLpForm, optimizer, ::Formulation, ::OptimizationState) # fallback
    error("Cannot optimize LP formulation with optimizer of type ", typeof(optimizer), ".")
end

function optimize_lp_form!(
    algo::SolveLpForm, optimizer::MoiOptimizer, form::Formulation, result::OptimizationState
)
    moi_params = MoiOptimize(
        time_limit = 3600, # TODO: expose
        deactivate_artificial_vars = false,
        enforce_integrality = false,
        relax_integrality = algo.relax_integrality,
        get_dual_bound = algo.get_dual_bound,
        get_dual_solution = algo.get_dual_sol,
        silent = algo.silent
    )
    optimize_with_moi!(optimizer, form, moi_params, result)
    return
end

function run!(
    algo::SolveLpForm, ::Env, form::Formulation, input::OptimizationState, 
    optimizer_id::Int = 1
)
    result = OptimizationState(form)

    TO.@timeit Coluna._to "SolveLpForm" begin

    if algo.relax_integrality
        relax_integrality!(form)
    end

    optimizer = getoptimizer(form, optimizer_id)
    optimize_lp_form!(algo, optimizer, form, result)
    primal_sols = get_primal_solutions(form, optimizer)

    coeff = getobjsense(form) == MinSense ? 1.0 : -1.0

    if algo.get_dual_sol
        dual_sols = get_dual_solutions(form, optimizer)
        if length(dual_sols) > 0
            lp_dual_sol_pos = argmax(coeff * getvalue.(dual_sols))
            lp_dual_sol = dual_sols[lp_dual_sol_pos]
            set_lp_dual_sol!(result, lp_dual_sol)
            if algo.get_dual_bound
                db = DualBound(form, getvalue(lp_dual_sol))
                set_lp_dual_bound!(result, db)
            end
        end
    end

    if length(primal_sols) > 0
        lp_primal_sol_pos = argmin(coeff * getvalue.(primal_sols))
        lp_primal_sol = primal_sols[lp_primal_sol_pos]
        add_lp_primal_sol!(result, lp_primal_sol)
        pb = PrimalBound(form, getvalue(lp_primal_sol))
        set_lp_primal_bound!(result, pb)
        if algo.get_ip_primal_sol && isinteger(lp_primal_sol) && 
            !contains(lp_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
            add_ip_primal_sol!(result, lp_primal_sol)
        end
    end
    end # @timeit
    return result
end

"""
    Coluna.Algorithm.SolveIpForm(
        time_limit::Int = 600,
        deactivate_artificial_vars = true,
        enforce_integrality = true,
        silent = true,
        max_nb_ip_primal_sols = 50,
        log_level = 0
    )

Solve a mixed integer linear program.
"""
@with_kw struct SolveIpForm <: AbstractOptimizationAlgorithm
    time_limit::Int = 600
    deactivate_artificial_vars = true
    enforce_integrality = true
    get_dual_bound = true
    silent = true
    max_nb_ip_primal_sols = 50
    log_level = 0
end

# SolveIpForm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_units_usage(
    algo::SolveIpForm, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storage units in the read only mode, as all modifications
    # (deactivating artificial vars and enforcing integrality)
    # are reverted before the end of the algorithm,
    # so the state of the formulation remains the same
    units_usage = Tuple{AbstractModel, UnitType, UnitAccessMode}[] 
    push!(units_usage, (form, StaticVarConstrUnit, READ_ONLY))
    if Duty <: MathProg.AbstractMasterDuty
        push!(units_usage, (form, PartialSolutionUnit, READ_ONLY))
        push!(units_usage, (form, MasterColumnsUnit, READ_ONLY))
        push!(units_usage, (form, MasterBranchConstrsUnit, READ_ONLY))
        push!(units_usage, (form, MasterCutsUnit, READ_ONLY))
    end
    return units_usage
end

get_units_usage(algo::SolveIpForm, reform::Reformulation) =
    get_units_usage(algo, getmaster(reform))

function check_if_optimizer_supports_ip(optimizer::MoiOptimizer)
    return MOI.supports_constraint(optimizer.inner, MOI.SingleVariable, MOI.Integer)
end
check_if_optimizer_supports_ip(optimizer::UserOptimizer) = false
check_if_optimizer_supports_ip(optimizer::NoOptimizer) = false

function run!(
    algo::SolveIpForm, env::Env, form::Formulation, input::OptimizationInput, 
    optimizer_id::Int = 1
)::OptimizationOutput
    result = OptimizationState(
        form, 
        ip_primal_bound = get_ip_primal_bound(getoptstate(input)),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    ip_supported = check_if_optimizer_supports_ip(getoptimizer(form, optimizer_id))
    if !ip_supported
        @warn "Optimizer of formulation with id =", getuid(form),
              " does not support integer variables. Skip SolveIpForm algorithm."
        setterminationstatus!(result, UNKNOWN_TERMINATION_STATUS)
        return OptimizationOutput(result)
    end

    primal_sols = optimize_ip_form!(algo, getoptimizer(form, optimizer_id), form, result)

    partial_sol = nothing
    partial_sol_value = 0.0
    if isa(form, Formulation{MathProg.DwMaster})
        partsolunit = getstorageunit(form, PartialSolutionUnit)
        partial_sol = get_primal_solution(partsolunit, form)
        partial_sol_value = getvalue(partial_sol)
    end
    
    if length(primal_sols) > 0
        if partial_sol !== nothing
            for primal_sol in primal_sols
                add_ip_primal_sol!(result, cat(partial_sol, primal_sol))
            end
        else
            for primal_sol in primal_sols
                add_ip_primal_sol!(result, primal_sol)
            end
        end
        if algo.log_level == 0
            @printf "Found primal solution of %.4f \n" getvalue(get_ip_primal_bound(result))
        end
        @logmsg LogLevel(-3) get_best_ip_primal_sol(result)
    else
        if algo.log_level == 0
            println(
                "No primal solution found. Termination status is ",
                getterminationstatus(result), ". "
            )
        end
    end
    if algo.get_dual_bound && getterminationstatus(result) == OPTIMAL
        dual_bound = getvalue(get_ip_primal_bound(result)) + partial_sol_value
        set_ip_dual_bound!(result, DualBound(form, dual_bound))
    end

    return OptimizationOutput(result)
end

run!(algo::SolveIpForm, env::Env, reform::Reformulation, input::OptimizationInput) = 
    run!(algo, env, getmaster(reform), input)

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
    nbvars = MOI.get(optimizer.inner, MOI.NumberOfVariables())
    if nbvars <= 0
        @warn "No variable in the formulation."
    end
    MOI.optimize!(getinner(optimizer))
    termination_status!(result, optimizer)
    return
end

function optimize_ip_form!(
    algo::SolveIpForm, optimizer::MoiOptimizer, form::Formulation, result::OptimizationState
)
    MOI.set(optimizer.inner, MOI.TimeLimitSec(), algo.time_limit)
    MOI.set(optimizer.inner, MOI.Silent(), algo.silent)
    # No way to enforce upper bound or lower bound through MOI.
    # Add a constraint c'x <= UB in form ?

    if algo.deactivate_artificial_vars
        deactivate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
    end
    if algo.enforce_integrality
        enforce_integrality!(form)
    end

    optimize_with_moi!(optimizer, form, result)
    primal_sols = get_primal_solutions(form, optimizer)

    if algo.enforce_integrality
        relax_integrality!(form)
    end
    if algo.deactivate_artificial_vars
        activate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
    end
    return primal_sols
end

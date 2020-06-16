"""
    Coluna.Algorithm.SolveIpForm(
        time_limit::Int = 600,
        deactivate_artificial_vars = true,
        enforce_integrality = true,
        silent = true,
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
    log_level = 0
end

function get_storages_usage!(
    algo::SolveIpForm, form::Formulation{Duty}, storages_usage::StoragesUsageDict
) where {Duty<:MathProg.AbstractFormDuty}
    add_storage!(storages_usage, form, StaticVarConstrStorage)
    if Duty <: MathProg.AbstractMasterDuty
        add_storage!(storages_usage, form, MasterColumnsStorage)
        add_storage!(storages_usage, form, MasterBranchConstrsStorage)
        add_storage!(storages_usage, form, MasterCutsStorage)
    end
end

function get_storages_to_restore!(
    algo::SolveIpForm, form::Formulation{Duty}, storages_to_restore::StoragesToRestoreDict
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storages in the read only mode, as all modifications
    # (deactivating artificial vars and enforcing integrality)
    # are reverted before the end of the algorithm,
    # so the state of the formulation remains the same
    add_storage!(storages_to_restore, form, StaticVarConstrStorage, READ_ONLY)
    if Duty <: MathProg.AbstractMasterDuty
        add_storage!(storages_to_restore, form, MasterColumnsStorage, READ_ONLY)
        add_storage!(storages_to_restore, form, MasterBranchConstrsStorage, READ_ONLY)
        add_storage!(storages_to_restore, form, MasterCutsStorage, READ_ONLY)
    end
end

# TO DO : create an Algorithm Logger
# function Logging.shouldlog(logger::ConsoleLogger, level, _module, group, id)
#     println("*******")
#     @show level _module group id
#     println("log = ", get(logger.message_limits, id, 1))
#     println("******")
#     return get(logger.message_limits, id, 1) > 0
# end

function run!(algo::SolveIpForm, data::ModelData, input::OptimizationInput)::OptimizationOutput

    form = getmodel(data)
    optstate = OptimizationState(
        form, ip_primal_bound = get_ip_primal_bound(getoptstate(input))
    )

    ip_supported = check_if_optimizer_supports_ip(getoptimizer(form))
    if !ip_supported
        @warn "Optimizer of formulation with id =", getuid(form),
              " does not support integer variables. Skip SolveIpForm algorithm."
        setterminationstatus!(optstate, EMPTY_RESULT)
        return OptimizationOutput(optstate)
    end

    optimizer_result = optimize_ip_form!(algo, getoptimizer(form), form)

    setfeasibilitystatus!(optstate, getfeasibilitystatus(optimizer_result))
    setterminationstatus!(optstate, getterminationstatus(optimizer_result))

    bestprimalsol = getbestprimalsol(optimizer_result)
    if bestprimalsol !== nothing
        add_ip_primal_sol!(optstate, bestprimalsol)
        if algo.log_level == 0
            @printf "Found primal solution of %.4f \n" getvalue(get_ip_primal_bound(optstate))
        end
        @logmsg LogLevel(-3) get_best_ip_primal_sol(optstate)
    else
        if algo.log_level == 0
            println(
                "No primal solution found. Termination status is ",
                getterminationstatus(optstate), ". Feasibility status is ",
                getfeasibilitystatus(optstate), "."
            )
        end
    end
    if algo.get_dual_bound && getterminationstatus(optimizer_result) == OPTIMAL
        # TO DO : dual bound should be set in optimizer_result
        set_ip_dual_bound!(optstate, DualBound(form, getvalue(getprimalbound(optimizer_result))))
    end
    return OptimizationOutput(optstate)
end

function check_if_optimizer_supports_ip(optimizer::MoiOptimizer)
    return MOI.supports_constraint(optimizer.inner, MOI.SingleVariable, MOI.Integer)
end
check_if_optimizer_supports_ip(optimizer::UserOptimizer) = true

function optimize_ip_form!(algo::SolveIpForm, optimizer::MoiOptimizer, form::Formulation)
    MOI.set(optimizer.inner, MOI.TimeLimitSec(), algo.time_limit)
    MOI.set(optimizer.inner, MOI.Silent(), algo.silent)
    # No way to enforce upper bound through MOI.
    # Add a constraint c'x <= UB in form ?

    if algo.deactivate_artificial_vars
        deactivate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
    end
    if algo.enforce_integrality
        enforce_integrality!(form)
    end

    optimizer_result = optimize!(form)

    if algo.enforce_integrality
        relax_integrality!(form)
    end
    if algo.deactivate_artificial_vars
        activate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
    end
    return optimizer_result
end

function optimize_ip_form!(algo::SolveIpForm, optimizer::UserOptimizer, form::Formulation)
    return optimize!(form)
end

run!(alg::SolveIpForm, rfdata::ReformData, input::OptimizationInput) =
    run!(alg, getmasterdata(rfdata), input)

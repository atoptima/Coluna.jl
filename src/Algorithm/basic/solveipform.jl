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

# SolveIpForm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_storages_usage(
    algo::SolveIpForm, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storages in the read only mode, as all modifications
    # (deactivating artificial vars and enforcing integrality)
    # are reverted before the end of the algorithm,
    # so the state of the formulation remains the same
    storages_usage = Tuple{AbstractModel, StorageTypePair, StorageAccessMode}[] 
    push!(storages_usage, (form, StaticVarConstrStoragePair, READ_ONLY))
    if Duty <: MathProg.AbstractMasterDuty
        push!(storages_usage, (form, MasterColumnsStoragePair, READ_ONLY))
        push!(storages_usage, (form, MasterBranchConstrsStoragePair, READ_ONLY))
        push!(storages_usage, (form, MasterCutsStoragePair, READ_ONLY))
    end
    return storages_usage
end

get_storages_usage(algo::SolveIpForm, reform::Reformulation) =
    get_storages_usage(algo, getmaster(reform))

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

run!(algo::SolveIpForm, data::ReformData, input::OptimizationInput) = 
    run!(algo, getmasterdata(data), input)

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

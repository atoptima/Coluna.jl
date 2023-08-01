################################################################################
# Algorithm
################################################################################
"""
    Coluna.Algorithm.SolveIpForm(
        optimizer_id = 1
        moi_params = MoiOptimize()
        user_params = UserOptimize()
        custom_params = CustomOptimize()
    )

Solve an optimization problem. This algorithm can call different type of optimizers :
- subsolver interfaced with MathOptInterface to optimize a mixed integer program
- pricing callback defined by the user
- custom optimizer to solve a custom model

You can specify an optimizer using the `default_optimizer` attribute of Coluna or
with the method `specify!` from BlockDecomposition.
If you want to define several optimizers for a given subproblem, you must use `specify!`:

    specify!(subproblem, optimizers = [optimizer1, optimizer2, optimizer3])

Value of `optimizer_id` is the position of the optimizer you want to use.
For example, if `optimizer_id` is equal to 2, the algorithm will use `optimizer2`.

By default, the algorihm uses the first optimizer or the default optimizer if no
optimizer has been specified through `specify!`.

Depending on the type of the optimizer chosen, the algorithm will use one the 
three configurations : 
- `moi_params` for subsolver interfaced with MathOptInterface
- `user_params` for pricing callbacks
- `custom_params` for custom solvers

Custom solver is undocumented because alpha.
"""
struct SolveIpForm <: AbstractOptimizationAlgorithm
    optimizer_id::Int
    moi_params::MoiOptimize
    user_params::UserOptimize
    custom_params::CustomOptimize
    SolveIpForm(;
        optimizer_id = 1,
        moi_params = MoiOptimize(),
        user_params = UserOptimize(),
        custom_params = CustomOptimize()
    ) = new(optimizer_id, moi_params, user_params, custom_params)
end

# SolveIpForm does not have child algorithms, therefore get_child_algorithms() is not defined

# Dispatch on the type of the optimizer to return the parameters
_optimizer_params(::Formulation, algo::SolveIpForm, ::MoiOptimizer) = algo.moi_params
_optimizer_params(::Formulation, algo::SolveIpForm, ::UserOptimizer) = algo.user_params
_optimizer_params(form::Formulation, algo::SolveIpForm, ::CustomOptimizer) = getinner(getoptimizer(form, algo.optimizer_id))
_optimizer_params(::Formulation, ::SolveIpForm, ::NoOptimizer) = nothing

function run!(algo::SolveIpForm, env::Env, form::Formulation, input::OptimizationState, optimizer_id = 1)
    opt = getoptimizer(form, algo.optimizer_id)
    params = _optimizer_params(form, algo, opt)
    if params !== nothing
        return run!(params, env, form, input; optimizer_id = algo.optimizer_id)
    end
    return error("Cannot optimize formulation with optimizer of type $(typeof(opt)).")
end

run!(algo::SolveIpForm, env::Env, reform::Reformulation, input::OptimizationState) = 
    run!(algo, env, getmaster(reform), input)

################################################################################
# Get units usage (depends on the type of the optimizer)
################################################################################
function get_units_usage(algo::SolveIpForm, form::Formulation)
    opt = getoptimizer(form, algo.optimizer_id)
    params = _optimizer_params(form, algo, opt)
    if params !== nothing
        return get_units_usage(params, form)
    end
    return error("Cannot get units usage of optimizer of type $(typeof(opt)).")
end

# get_units_usage of MoiOptimize
function get_units_usage(
    ::MoiOptimize, form::Formulation{Duty}
) where {Duty<:MathProg.AbstractFormDuty}
    # we use storage units in the read only mode, as all modifications
    # (deactivating artificial vars and enforcing integrality)
    # are reverted before the end of the algorithm,
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

get_units_usage(algo::SolveIpForm, reform::Reformulation) = 
    get_units_usage(algo, getmaster(reform))

# get_units_usage of UserOptimize
function get_units_usage(::UserOptimize, spform::Formulation{DwSp}) 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[] 
    return units_usage
end

# no get_units_usage of CustomOptimize because it directly calls the
# get_units_usage of the custom optimizer

################################################################################
# run! methods (depends on the type of the optimizer)
################################################################################

function check_if_optimizer_supports_ip(optimizer::MoiOptimizer)
    return MOI.supports_constraint(optimizer.inner, MOI.VariableIndex, MOI.Integer)
end
check_if_optimizer_supports_ip(optimizer::UserOptimizer) = false
check_if_optimizer_supports_ip(optimizer::NoOptimizer) = false

# run! of MoiOptimize
function run!(
    algo::MoiOptimize, ::Env, form::Formulation, input::OptimizationState; 
    optimizer_id::Int = 1
)
    result = OptimizationState(
        form, 
        ip_primal_bound = get_ip_primal_bound(input),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    optimizer = getoptimizer(form, optimizer_id)
    ip_supported = check_if_optimizer_supports_ip(optimizer)
    if !ip_supported
        @warn "Optimizer of formulation with id =", getuid(form),
              " does not support integer variables. Skip SolveIpForm algorithm."
        return result
    end

    primal_sols = optimize_ip_form!(algo, optimizer, form, result)

    if length(primal_sols) > 0
        for primal_sol in primal_sols
            add_ip_primal_sol!(result, primal_sol)
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
        dual_bound = getvalue(get_ip_primal_bound(result))
        set_ip_dual_bound!(result, DualBound(form, dual_bound))
        set_lp_dual_bound!(result, DualBound(form, dual_bound))
    end
    if algo.get_dual_solution && getterminationstatus(result) == OPTIMAL
        dual_sols = get_dual_solutions(form, optimizer)
        if length(dual_sols) > 0
            coeff = getobjsense(form) == MinSense ? 1.0 : -1.0
            lp_dual_sol_pos = argmax(coeff * getvalue.(dual_sols))
            lp_dual_sol = dual_sols[lp_dual_sol_pos]
            set_lp_dual_sol!(result, lp_dual_sol)
        end
    end

    return result
end

function optimize_ip_form!(
    algo::MoiOptimize, optimizer::MoiOptimizer, form::Formulation, result::OptimizationState
)
    # No way to enforce upper bound or lower bound through MOI.
    # We must add a constraint c'x <= UB in formulation.

    if algo.deactivate_artificial_vars
        deactivate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
    end
    if algo.enforce_integrality
        enforce_integrality!(form)
    end

    optimize_with_moi!(optimizer, form, algo, result)
    primal_sols = get_primal_solutions(form, optimizer)

    if algo.enforce_integrality
        relax_integrality!(form)
    end
    if algo.deactivate_artificial_vars
        activate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
    end
    return primal_sols
end


# errors for the pricing callback
"""
    IncorrectPricingDualBound

Error thrown when transmitting a dual bound larger than the primal bound of the 
best solution to the pricing subproblem found in a run of the pricing callback.
"""
struct IncorrectPricingDualBound
    pb::ColunaBase.Bound
    db::Union{Nothing,ColunaBase.Bound}
end

"""
    MissingPricingDualBound

Error thrown when the pricing callback does not transmit any dual bound.
Make sure you call `MOI.submit(model, BD.PricingDualBound(cbdata), db)` in your pricing
callback.
"""
struct MissingPricingDualBound end

"""
    MultiplePricingDualBounds

Error thrown when the pricing transmits multiple dual bound.
Make sure you call `MOI.submit(model, BD.PricingDualBound(cbdata), db)` only once in your 
pricing callback.
"""
struct MultiplePricingDualBounds 
    nb_dual_bounds::Int
end

# run! of UserOptimize
function run!(
    algo::UserOptimize, ::Env, spform::Formulation{DwSp}, input::OptimizationState;
    optimizer_id::Int = 1
)
    result = OptimizationState(
        spform, 
        ip_primal_bound = get_ip_primal_bound(input),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    optimizer = getoptimizer(spform, optimizer_id)
    cbdata = MathProg.PricingCallbackData(spform)
    optimizer.user_oracle(cbdata)

    if cbdata.nb_times_dual_bound_set == 0
        throw(MissingPricingDualBound())
    elseif cbdata.nb_times_dual_bound_set > 1
        throw(MultiplePricingDualBounds(cbdata.nb_times_dual_bound_set))
    end

    # If the user does not submit any primal solution, we consider the primal as infeasible.
    primal_infeasible = length(cbdata.primal_solutions) == 0

    # If the dual bound from the pricing callback data is nothing, we consider the dual as 
    # infeasible.
    dual_infeasible = isnothing(cbdata.dual_bound)

    set_ip_dual_bound!(result, DualBound(spform, cbdata.dual_bound))
    db = get_ip_dual_bound(result)

    for primal_sol in cbdata.primal_solutions
        add_ip_primal_sol!(result, primal_sol)
    end

    pb = get_ip_primal_bound(result)

    if primal_infeasible && isunbounded(db)
        setterminationstatus!(result, INFEASIBLE)
        set_ip_primal_bound!(result, nothing)
    elseif isunbounded(pb) && dual_infeasible
        setterminationstatus!(result, UNBOUNDED)
        set_ip_dual_bound!(result, nothing)
    elseif abs(gap(pb, db)) <= 1e-4
        setterminationstatus!(result, OPTIMAL)
    elseif gap(pb, db) < -1e-4
        throw(IncorrectPricingDualBound(pb, db))
    else
        setterminationstatus!(result, OTHER_LIMIT)
    end
    return result
end

# No run! method for CustomOptimize because it directly calls the run! method
# of the custom optimizer
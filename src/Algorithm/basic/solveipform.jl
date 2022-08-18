################################################################################
# Parameters for each type of optimizer
################################################################################
"""
    MoiOptimize(
        time_limit = 600
        deactivate_artificial_vars = false
        enforce_integrality = false
        get_dual_bound = true
    )

Configuration for an optimizer that calls a subsolver through MathOptInterface.

Parameters:
- `time_limit`: in seconds
- `deactivate_artificial_vars`: deactivate all artificial variables of the formulation if equals `true`
- `enforce_integrality`: enforce integer variables that are relaxed if equals `true`
- `get_dual_bound`: store the dual objective value in the output if equals `true`
"""
@with_kw struct MoiOptimize
    time_limit::Int = 600
    deactivate_artificial_vars::Bool = true
    enforce_integrality::Bool = true
    get_dual_bound::Bool = true
    get_dual_solution::Bool = false # Used in MOI integration tests.
    max_nb_ip_primal_sols::Int = 50
    log_level::Int = 2
    silent::Bool = true
end

"""
    UserOptimize(
        max_nb_ip_primal_sols = 50
    )

Configuration for an optimizer that calls a pricing callback to solve the problem.

Parameters:
- `max_nb_ip_primal_sols`: maximum number of solutions returned by the callback kept
"""
@with_kw struct UserOptimize
    max_nb_ip_primal_sols::Int = 50
end

"""
    CustomOptimize()

Configuration for an optimizer that calls a custom solver to solve a custom model.
"""
struct CustomOptimize end

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
@with_kw struct SolveIpForm <: AbstractOptimizationAlgorithm
    optimizer_id::Int = 1
    moi_params::MoiOptimize = MoiOptimize()
    user_params::UserOptimize = UserOptimize()
    custom_params::CustomOptimize = CustomOptimize()
end

# SolveIpForm does not have child algorithms, therefore get_child_algorithms() is not defined

# Dispatch on the type of the optimizer to return the parameters
_optimizer_params(::Formulation, algo::SolveIpForm, ::MoiOptimizer) = algo.moi_params
_optimizer_params(::Formulation, algo::SolveIpForm, ::UserOptimizer) = algo.user_params
_optimizer_params(form::Formulation, algo::SolveIpForm, ::CustomOptimizer) = getinner(getoptimizer(form, algo.optimizer_id))
_optimizer_params(::Formulation, ::SolveIpForm, ::NoOptimizer) = nothing

function run!(algo::SolveIpForm, env::Env, form::Formulation, input::OptimizationInput)::OptimizationOutput
    opt = getoptimizer(form, algo.optimizer_id)
    params = _optimizer_params(form, algo, opt)
    if params !== nothing
        return run!(params, env, form, input; optimizer_id = algo.optimizer_id)
    end
    return error("Cannot optimize formulation with optimizer of type $(typeof(opt)).")
end

run!(algo::SolveIpForm, env::Env, reform::Reformulation, input::OptimizationInput) = 
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
        push!(units_usage, (form, PartialSolutionUnit, READ_ONLY))
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
    #push!(units_usage, (spform, StaticVarConstrUnit, READ_ONLY))
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
    algo::MoiOptimize, ::Env, form::Formulation, input::OptimizationInput; 
    optimizer_id::Int = 1
)::OptimizationOutput
    result = OptimizationState(
        form, 
        ip_primal_bound = get_ip_primal_bound(get_opt_state(input)),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    optimizer = getoptimizer(form, optimizer_id)
    ip_supported = check_if_optimizer_supports_ip(optimizer)
    if !ip_supported
        @warn "Optimizer of formulation with id =", getuid(form),
              " does not support integer variables. Skip SolveIpForm algorithm."
        return OptimizationOutput(result)
    end

    primal_sols = optimize_ip_form!(algo, optimizer, form, result)

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

    return OptimizationOutput(result)
end

function optimize_ip_form!(
    algo::MoiOptimize, optimizer::MoiOptimizer, form::Formulation, result::OptimizationState
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


# errors for the pricing callback
"""
    IncorrectPricingDualBound

Error thrown when transmitting a dual bound larger than the primal bound of the 
best solution to the pricing subproblem found in a run of the pricing callback.
"""
struct IncorrectPricingDualBound{Sense}
    pb::PrimalBound{Sense}
    db::DualBound{Sense}
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
    algo::UserOptimize, ::Env, spform::Formulation{DwSp}, input::OptimizationInput;
    optimizer_id::Int = 1
)::OptimizationOutput
    result = OptimizationState(
        spform, 
        ip_primal_bound = get_ip_primal_bound(get_opt_state(input)),
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

    for primal_sol in cbdata.primal_solutions
        add_ip_primal_sol!(result, primal_sol)
    end
    set_ip_dual_bound!(result, DualBound(spform, cbdata.dual_bound))

    pb = get_ip_primal_bound(result)
    db = get_ip_dual_bound(result)
    if isunbounded(db)
        setterminationstatus!(result, INFEASIBLE)
    elseif isinfeasible(db)
        setterminationstatus!(result, DUAL_INFEASIBLE)
    elseif abs(gap(pb, db)) <= 1e-4
        setterminationstatus!(result, OPTIMAL)
    elseif gap(pb, db) < -1e-4
        throw(IncorrectPricingDualBound(pb, db))
    else
        setterminationstatus!(result, OTHER_LIMIT)
    end
    return OptimizationOutput(result)
end

# No run! method for CustomOptimize because it directly calls the run! method
# of the custom optimizer
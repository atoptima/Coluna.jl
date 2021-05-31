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

User parameters for an optimizer that calls a subsolver through MathOptInterface.
"""
@with_kw struct MoiOptimize
    time_limit::Int = 600
    deactivate_artificial_vars::Bool = true
    enforce_integrality::Bool = true
    get_dual_bound::Bool = true
    max_nb_ip_primal_sols::Int = 50
    log_level::Int = 2
    silent::Bool = true
end

"""
    UserOptimize(
        stage = 1
        max_nb_ip_primal_sols = 50
    )

User parameters for an optimizer that calls a callback to solve the problem.
"""
@with_kw struct UserOptimize
    stage::Int = 1
    max_nb_ip_primal_sols::Int = 50
end

"""
    CustomOptimize()

User parameters for an optimizer that calls a custom solver to solve a custom model.
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

Solve an optimization problem. It can call a :
- subsolver through MathOptInterface to optimize a mixed integer program
- pricing callback defined by the user
- custom optimizer to solve a custom model

The algorithms calls optimizer with id `optimizer_id`.
The user can specify different optimizers using the method `BlockDecomposition.specify!`.
In that case `optimizer_id` is the position of the optimizer in the array of optimizers
passed to `specify!`.
By default, the algorihm uses the first optimizer or the default optimizer if no
optimizer has been specified.

Depending on the type of the optimizer chosen, the algorithm will use one the 
three configurations : `moi_params`, `user_params`, or `custom_params`.
"""
@with_kw struct SolveIpForm <: AbstractOptimizationAlgorithm
    optimizer_id::Int = 1
    moi_params::MoiOptimize = MoiOptimize()
    user_params::UserOptimize = UserOptimize()
    custom_params::CustomOptimize = CustomOptimize()
end

# SolveIpForm does not have child algorithms, therefore get_child_algorithms() is not defined

# Dispatch on the type of the optimizer to return the parameters
_optimizer_params(algo::SolveIpForm, ::MoiOptimizer) = algo.moi_params
_optimizer_params(algo::SolveIpForm, ::UserOptimizer) = algo.user_params
# TODO : custom optimizer
_optimizer_params(::SolveIpForm, ::NoOptimizer) = nothing

function run!(algo::SolveIpForm, env::Env, form::Formulation, input::OptimizationInput)::OptimizationOutput
    opt = getoptimizer(form, algo.optimizer_id)
    params = _optimizer_params(algo, opt)
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
    params = _optimizer_params(algo, opt)
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

# get_units_usage of UserOptimize
function get_units_usage(::UserOptimize, spform::Formulation{DwSp}) 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[] 
    push!(units_usage, (spform, StaticVarConstrUnit, READ_ONLY))
    return units_usage
end

# TODO : get_units_usage of CustomOptimize

################################################################################
# run! methods (depends on the type of the optimizer)
################################################################################

function check_if_optimizer_supports_ip(optimizer::MoiOptimizer)
    return MOI.supports_constraint(optimizer.inner, MOI.SingleVariable, MOI.Integer)
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

# run! of UserOptimize
function run!(
    algo::UserOptimize, ::Env, spform::Formulation{DwSp}, input::OptimizationInput;
    optimizer_id::Int = 1
)::OptimizationOutput
    result = OptimizationState(
        spform, 
        ip_primal_bound = get_ip_primal_bound(getoptstate(input)),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    optimizer = getoptimizer(spform, optimizer_id)
    cbdata = MathProg.PricingCallbackData(spform, algo.stage)
    optimizer.user_oracle(cbdata)

    if length(cbdata.primal_solutions) > 0
        for primal_sol in cbdata.primal_solutions
            add_ip_primal_sol!(result, primal_sol)
        end

        if algo.stage == 1 # stage 1 is exact by convention
            dual_bound = getvalue(get_ip_primal_bound(result))
            set_ip_dual_bound!(result, DualBound(spform, dual_bound))
            setterminationstatus!(result, OPTIMAL) 
        else    
            setterminationstatus!(result, OTHER_LIMIT) 
        end
    else
        if algo.stage == 1    
            setterminationstatus!(result, INFEASIBLE) 
        else
            setterminationstatus!(result, OTHER_LIMIT) 
        end 
    end
    return OptimizationOutput(result)
end

# TODO : run! of CustomOptimize
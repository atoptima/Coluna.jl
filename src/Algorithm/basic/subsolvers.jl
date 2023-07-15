################################################################################
# Parameters for each type of optimizer (subsolver).
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
    relax_integrality::Bool = false
    get_dual_bound::Bool = true
    get_dual_solution::Bool = false # Used in MOI integration tests.
    max_nb_ip_primal_sols::Int = 50
    log_level::Int = 2
    silent::Bool = true
    custom_parameters = Dict{String,Any}()
end

function _get_cur_optimizer_params(optimizer::MoiOptimizer, algo::MoiOptimize)
    moi_parameters = Dict{DataType, Any}()
    for param_type in [MOI.TimeLimitSec, MOI.Silent]
        moi_parameters[param_type] = MOI.get(optimizer.inner, param_type())
    end

    raw_parameters = Dict{String, Any}()
    for name in Iterators.keys(algo.custom_parameters)
        raw_parameters[name] = MOI.get(optimizer.inner, MOI.RawOptimizerAttribute(name))
    end
    return moi_parameters, raw_parameters
end

function _set_optimizer_params!(optimizer::MoiOptimizer, moi_parameters, raw_parameters)
    for (param_type, value) in moi_parameters
        MOI.set(optimizer.inner, param_type(), value)
    end

    for (param_name, value) in raw_parameters
        MOI.set(optimizer.inner, MOI.RawOptimizerAttribute(param_name), value)
    end
    return
end

function _termination_status!(result::OptimizationState, optimizer::MoiOptimizer)
    termination_status = MOI.get(getinner(optimizer), MOI.TerminationStatus())
    coluna_termination_status = convert_status(termination_status)

    if coluna_termination_status == OPTIMAL
        if MOI.get(getinner(optimizer), MOI.ResultCount()) <= 0
            msg = """
            Termination status = $(termination_status) but no results.
            Please, open an issue at https://github.com/atoptima/Coluna.jl/issues
            """
            error(msg)
        end
    end
    setterminationstatus!(result, coluna_termination_status)
    return
end

function optimize_with_moi!(
    optimizer::MoiOptimizer, form::Formulation, algo::MoiOptimize, result::OptimizationState
)
    # Set parameters.
    cur_moi_params = Dict(
        MOI.TimeLimitSec => algo.time_limit,
        MOI.Silent => algo.silent
    )
    cur_raw_params = algo.custom_parameters
    _set_optimizer_params!(optimizer, cur_moi_params, cur_raw_params)

    # Synchronize the subsolver by transmitting all buffered formulation changes.
    sync_solver!(optimizer, form)

    nbvars = MOI.get(optimizer.inner, MOI.NumberOfVariables())
    if nbvars <= 0
        @warn "No variable in the formulation."
    end

    # Solve.
    MOI.optimize!(getinner(optimizer))

    # Retrieve termination status from MOI and convert into Coluna termination status.
    _termination_status!(result, optimizer)
    return
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

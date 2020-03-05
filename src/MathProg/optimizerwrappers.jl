"""
    NoOptimizer <: AbstractOptimizer

Wrapper to indicate that no optimizer is assigned to a `Formulation`
"""
struct NoOptimizer <: AbstractOptimizer end

no_optimizer_builder(args...) = NoOptimizer()

"""
    UserOptimizer <: AbstractOptimizer

Wrapper that is used when the `optimize!(f::Formulation)` function should call an user-defined callback.
"""
mutable struct UserOptimizer <: AbstractOptimizer
    user_oracle::Function
end

mutable struct OracleData 
    form::Formulation
    result::Union{Nothing, OptimizationResult}
end

function optimize!(form::Formulation, optimizer::UserOptimizer)
    @logmsg LogLevel(-2) "Calling user-defined optimization function."
    od = OracleData(form, nothing)
    optimizer.user_oracle(od)
    return od.result
end

"""
    MoiOptimizer <: AbstractOptimizer

Wrapper that is used when the optimizer of a formulation 
is an `MOI.AbstractOptimizer`, thus inheriting MOI functionalities.
"""
struct MoiOptimizer <: AbstractOptimizer
    inner::MOI.ModelLike
end

getinner(optimizer::MoiOptimizer) = optimizer.inner

function retrieve_result(form::Formulation, optimizer::MoiOptimizer)
    result = OptimizationResult{getobjsense(form)}()
    terminationstatus = MOI.get(getinner(optimizer), MOI.TerminationStatus())
    if terminationstatus != MOI.INFEASIBLE &&
            terminationstatus != MOI.DUAL_INFEASIBLE &&
            terminationstatus != MOI.INFEASIBLE_OR_UNBOUNDED &&
            terminationstatus != MOI.OPTIMIZE_NOT_CALLED
        fill_primal_result!(form, optimizer, result)
        fill_dual_result!(
        optimizer, result, filter(
                c -> iscuractive(form, c.first) && iscurexplicit(form, c.first), 
                getconstrs(form)
            )
        )
        if MOI.get(getinner(optimizer), MOI.ResultCount()) >= 1 
            setfeasibilitystatus!(result, FEASIBLE)
            setterminationstatus!(result, convert_status(terminationstatus))
        else
            msg = """
            Termination status = $(terminationstatus) but no results.
            Please, open an issue at https://github.com/atoptima/Coluna.jl/issues
            """
            error(msg)
        end
    else
        @warn "Solver has no result to show."
        setfeasibilitystatus!(result, INFEASIBLE)
        setterminationstatus!(result, EMPTY_RESULT)
    end
    return result
end

function optimize!(form::Formulation, optimizer::MoiOptimizer)
    @logmsg LogLevel(-4) "MOI formulation before synch: "
    @logmsg LogLevel(-4) getoptimizer(form)
    sync_solver!(getoptimizer(form), form)
    @logmsg LogLevel(-3) "MOI formulation after synch: "
    @logmsg LogLevel(-3) getoptimizer(form)
    nbvars = MOI.get(form.optimizer.inner, MOI.NumberOfVariables())
    if nbvars <= 0
        @warn "No variable in the formulation. Coluna does not call the solver."
        return retrieve_result(form, optimizer)
    end
    call_moi_optimize_with_silence(form.optimizer)
    status = MOI.get(form.optimizer.inner, MOI.TerminationStatus())
    @logmsg LogLevel(-2) string("Optimization finished with status: ", status)
    return retrieve_result(form, optimizer)
end

function sync_solver!(optimizer::MoiOptimizer, f::Formulation)
    @logmsg LogLevel(-1) string("Synching formulation ", getuid(f))
    buffer = f.buffer
    matrix = getcoefmatrix(f)

    # Remove constrs
    @logmsg LogLevel(-2) string("Removing constraints")
    remove_from_optimizer!(buffer.constr_buffer.removed, f)

    # Remove vars
    @logmsg LogLevel(-2) string("Removing variables")
    remove_from_optimizer!(buffer.var_buffer.removed, f)

    # Add vars
    for id in buffer.var_buffer.added
        v = getvar(f, id)
        @logmsg LogLevel(-4) string("Adding variable ", getname(f, v))
        add_to_optimizer!(f, v)
    end

    # Add constrs
    for constr_id in buffer.constr_buffer.added
        constr = getconstr(f, constr_id)
        @logmsg LogLevel(-4) string("Adding constraint ", getname(f, constr))
        add_to_optimizer!(f, constr, (f, constr) -> iscuractive(f, constr) && iscurexplicit(f, constr))  
    end

    # Update variable costs
    for id in buffer.changed_cost
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        update_cost_in_optimizer!(f, getvar(f, id))
    end

    # Update variable bounds
    for id in buffer.changed_bound
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-4) "Changing bounds of variable " getname(f, id)
        @logmsg LogLevel(-5) string("New lower bound is ", getcurlb(f, id))
        @logmsg LogLevel(-5) string("New upper bound is ", getcurub(f, id))
        update_bounds_in_optimizer!(f, getvar(f, id))
    end

    # Update variable kind
    for id in buffer.changed_var_kind
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing kind of variable " getname(f, id)
        @logmsg LogLevel(-3) string("New kind is ", getcurkind(f, id))
        enforce_kind_in_optimizer!(f, getvar(f,id))
    end

    # Update constraint rhs
    for id in buffer.changed_rhs
        (id in buffer.constr_buffer.added || id in buffer.constr_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing rhs of constraint " getname(f, id)
        @logmsg LogLevel(-3) string("New rhs is ", getcurrhs(f, id))
        update_constr_rhs_in_optimizer!(f, getconstr(f, id))
    end

    # Update matrix
    # First check if should update members of just-added vars
    matrix = getcoefmatrix(f)
    for id in buffer.var_buffer.added
        for (constrid, coeff) in  matrix[:,id]
            iscuractive(f, constrid) || continue
            iscurexplicit(f, constrid) || continue
            constrid ∉ buffer.constr_buffer.added || continue
            c = getconstr(f, constrid)
            update_constr_member_in_optimizer!(optimizer, c, getvar(f, id), coeff)
        end
    end

    # Then updated the rest of the matrix coeffs
    for ((c_id, v_id), coeff) in buffer.reset_coeffs
        # Ignore modifications involving vc's that were removed
        (c_id in buffer.constr_buffer.removed || v_id in buffer.var_buffer.removed) && continue
        c = getconstr(f, c_id)
        v = getvar(f, v_id)
        @logmsg LogLevel(-2) string("Setting matrix coefficient: (", getname(f, c), ",", getname(f, v), ") = ", coeff)
        # @logmsg LogLevel(1) string("Setting matrix coefficient: (", getname(c), ",", getname(v), ") = ", coeff)
        update_constr_member_in_optimizer!(optimizer, c, v, coeff)
    end
    _reset_buffer!(f)
    return
end

# Fallbacks
optimize!(f::Formulation, ::S) where {S<:AbstractOptimizer} = error(
    string("Function `optimize!` is not defined for object of type ", S)
)

# Initialization of optimizers
function _initialize_optimizer!(optimizer::MoiOptimizer, form::Formulation)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(form.optimizer.inner, MoiObjective(), f)
    set_obj_sense!(form.optimizer, getobjsense(form))
    return
end

_initialize_optimizer!(optimizer, form::Formulation) = return
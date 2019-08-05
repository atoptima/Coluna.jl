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
    optimize_function::Function
end

function optimize!(form::Formulation, optimizer::UserOptimizer)
    @logmsg LogLevel(-2) "Calling user-defined optimization function."
    return optimizer.optimize_function(form)
end

"""
    MoiOptimizer <: AbstractOptimizer

Wrapper that is used when the optimizer of a formulation 
is an `MOI.AbstractOptimizer`, thus inheriting MOI functionalities.
"""
struct MoiOptimizer <: AbstractOptimizer
    inner::MOI.AbstractOptimizer
end

getinner(optimizer::MoiOptimizer) = optimizer.inner

function retrieve_result(form::Formulation, optimizer::MoiOptimizer)
    result = OptimizationResult{getobjsense(form)}()
    if MOI.get(getinner(optimizer), MOI.ResultCount()) >= 1
        fill_primal_result!(
            optimizer, result, filter(_active_explicit_ , getvars(form))
        )
        fill_dual_result!(
            optimizer, result, filter(_active_explicit_ , getconstrs(form))
        )
        setfeasibilitystatus!(result, FEASIBLE)
        setterminationstatus!(
            result, convert_status(MOI.get(
                getinner(optimizer), MOI.TerminationStatus()
            ))
        )
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
        @logmsg LogLevel(-2) string("Adding variable ", getname(v))
        add_to_optimizer!(optimizer, v)
    end
    # Add constrs
    for id in buffer.constr_buffer.added
        c = getconstr(f, id)
        @logmsg LogLevel(-2) string("Adding constraint ", getname(c))
        add_to_optimizer!(optimizer, c, filter(_active_explicit_, matrix[id,:]))
    end
    # Update variable costs
    for id in buffer.changed_cost
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        update_cost_in_optimizer!(optimizer, getvar(f, id))
    end
    # Update variable bounds
    for id in buffer.changed_bound
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing bounds of variable " getname(getvar(f,id))
        @logmsg LogLevel(-3) string("New lower bound is ", getcurlb(getvar(f,id)))
        @logmsg LogLevel(-3) string("New upper bound is ", getcurub(getvar(f,id)))
        update_bounds_in_optimizer!(optimizer, getvar(f, id))
    end
    # Update variable kind
    for id in buffer.changed_kind
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing kind of variable " getname(getvar(f,id))
        @logmsg LogLevel(-3) string("New kind is ", getcurkind(getvar(f,id)))
        enforce_kind_in_optimizer!(optimizer, getvar(f,id))
    end
    # Update constraint rhs
    for id in buffer.changed_rhs
        (id in buffer.constr_buffer.added || id in buffer.constr_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing rhs of constraint " getname(getconstr(f,id))
        @logmsg LogLevel(-3) string("New rhs is ", getcurrhs(getconstr(f,id)))
        update_constr_rhs_in_optimizer!(optimizer, getconstr(f,id))
    end
    # Update matrix
    # First check if should update members of just-added vars
    matrix = getcoefmatrix(f)
    for id in buffer.var_buffer.added
        for (constr_id, coeff) in filter(_active_explicit_, matrix[:,id])
            constr_id in buffer.constr_buffer.added && continue
            c = getconstr(f, constr_id)
            update_constr_member_in_optimizer!(optimizer, c, getvar(f, id), coeff)
        end
    end
    # Then updated the rest of the matrix coeffs
    for ((c_id, v_id), coeff) in buffer.reset_coeffs
        # Ignore modifications involving vc's that were removed
        (c_id in buffer.constr_buffer.removed || v_id in buffer.var_buffer.removed) && continue
        c = getconstr(f, c_id)
        v = getvar(f, v_id)
        @logmsg LogLevel(-2) string("Setting matrix coefficient: (", getname(c), ",", getname(v), ") = ", coeff)
        # @logmsg LogLevel(1) string("Setting matrix coefficient: (", getname(c), ",", getname(v), ") = ", coeff)
        update_constr_member_in_optimizer!(optimizer, c, v, coeff)
    end
    _reset_buffer!(f)
    return
end

# Fallbacks
optimize!(::S) where {S<:AbstractOptimizer} = error(
    string("Function `optimize!` is not defined for object of type ", S)
)

"""
    NoOptimizer <: AbstractOptimizer

Wrapper when no optimizer is assigned to a formulation.
Basic algorithms that call an optimizer to optimize a formulation won't work.
"""
struct NoOptimizer <: AbstractOptimizer end

no_optimizer_builder(args...) = NoOptimizer()

"""
    UserOptimizer <: AbstractOptimizer

Wrap a julia function that acts like the optimizer of a formulation.
It is for example the function used as a pricing callback.
"""
mutable struct UserOptimizer <: AbstractOptimizer
    user_oracle::Function
end

mutable struct PricingCallbackData
    form::Formulation
    primal_solutions::Vector{PrimalSolution}
    nb_times_dual_bound_set::Int
    dual_bound::Union{Nothing, Float64}
end

function PricingCallbackData(form::F) where {F<:Formulation}
    return PricingCallbackData(form, PrimalSolution{F}[], 0, nothing)
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

function setbasis!(optimizer::MoiOptimizer) 
    
end

function sync_solver!(optimizer::MoiOptimizer, f::Formulation)
    @logmsg LogLevel(-1) string("Synching formulation ", getuid(f))
    buffer = f.buffer
    matrix = getcoefmatrix(f)

    # Remove constrs
    @logmsg LogLevel(-2) string("Removing constraints")
    remove_from_optimizer!(f, optimizer, buffer.constr_buffer.removed)

    # Remove vars
    @logmsg LogLevel(-2) string("Removing variables")
    remove_from_optimizer!(f, optimizer, buffer.var_buffer.removed)

    # Add vars
    for id in buffer.var_buffer.added
        v = getvar(f, id)
        @logmsg LogLevel(-4) string("Adding variable ", getname(f, v))
        add_to_optimizer!(f, optimizer, v)
    end

    # Add constrs
    for constr_id in buffer.constr_buffer.added
        constr = getconstr(f, constr_id)
        @logmsg LogLevel(-2) string("Adding constraint ", getname(f, constr))
        add_to_optimizer!(
            f, optimizer, constr, (f, constr) -> iscuractive(f, constr) && isexplicit(f, constr)
        )
    end

    # Update variable costs
    # TODO: Pass a new objective function if too many changes
    for id in buffer.changed_cost
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        update_cost_in_optimizer!(f, optimizer, getvar(f, id))
    end

    # Update objective sense
    if buffer.changed_obj_sense
        set_obj_sense!(optimizer, getobjsense(f))
        buffer.changed_obj_sense = false
    end

    # Update variable bounds
    for id in buffer.changed_bound
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-4) "Changing bounds of variable " getname(f, id)
        @logmsg LogLevel(-5) string("New lower bound is ", getcurlb(f, id))
        @logmsg LogLevel(-5) string("New upper bound is ", getcurub(f, id))
        update_bounds_in_optimizer!(f, optimizer, getvar(f, id))
    end

    # Update variable kind
    for id in buffer.changed_var_kind
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-3) "Changing kind of variable " getname(f, id)
        @logmsg LogLevel(-4) string("New kind is ", getcurkind(f, id))
        enforce_kind_in_optimizer!(f, optimizer, getvar(f,id))
    end

    # Update constraint rhs
    for id in buffer.changed_rhs
        (id in buffer.constr_buffer.added || id in buffer.constr_buffer.removed) && continue
        @logmsg LogLevel(-3) "Changing rhs of constraint " getname(f, id)
        @logmsg LogLevel(-4) string("New rhs is ", getcurrhs(f, id))
        update_constr_rhs_in_optimizer!(f, optimizer, getconstr(f, id))
    end

    # Update matrix
    # First check if should update members of just-added vars
    matrix = getcoefmatrix(f)
    for id in buffer.var_buffer.added
        for (constrid, coeff) in @view matrix[:,id]
            iscuractive(f, constrid) || continue
            isexplicit(f, constrid) || continue
            constrid ∉ buffer.constr_buffer.added || continue
            c = getconstr(f, constrid)
            update_constr_member_in_optimizer!(optimizer, c, getvar(f, id), coeff)
        end
    end

    # Then updated the rest of the matrix coeffs
    for ((c_id, v_id), coeff) in buffer.reset_coeffs
        # Ignore modifications involving vc's that were removed
        (c_id in buffer.constr_buffer.removed || v_id in buffer.var_buffer.removed) && continue
        iscuractive(f, c_id) && isexplicit(f, c_id) || continue
        iscuractive(f, v_id) && isexplicit(f, v_id) || continue
        c = getconstr(f, c_id)
        v = getvar(f, v_id)
        @logmsg LogLevel(-2) string("Setting matrix coefficient: (", getname(f, c), ",", getname(f, v), ") = ", coeff)
        update_constr_member_in_optimizer!(optimizer, c, v, coeff)
    end
    empty!(buffer)
    return
end

# Initialization of optimizers
function initialize_optimizer!(optimizer::MoiOptimizer, form::Formulation)
    f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
    MOI.set(optimizer.inner, MoiObjective(), f)
    set_obj_sense!(optimizer, getobjsense(form))
    return
end

initialize_optimizer!(optimizer, form::Formulation) = return
function write_to_LP_file(form::Formulation, optimizer::MoiOptimizer, filename::String)
    src = getinner(optimizer)
    dest = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_LP)
    MOI.copy_to(dest, src)
    MOI.write_to_file(dest, filename)
end

"""
    CustomOptimizer <: AbstractOptimizer

Undocumented because alpha.
"""
struct CustomOptimizer <: AbstractOptimizer
    inner::BD.AbstractCustomOptimizer
end

getinner(optimizer::CustomOptimizer) = optimizer.inner

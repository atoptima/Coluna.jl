"""
    VarConstrBuffer{T<:AbstractVarConstr}

A `VarConstrBuffer{T}` stores the ids of the entities to be added and removed from the formulation where it belongs.
"""
mutable struct VarConstrBuffer{T<:AbstractVarConstr}
    added::Set{Id{T}}
    removed::Set{Id{T}}
end

"""
    VarConstrBuffer{T}() where {T<:AbstractVarConstr}

Constructs an empty `VarConstrBuffer{T}` for entities of type `T`.
"""
VarConstrBuffer{T}() where {T<:AbstractVarConstr} = VarConstrBuffer{T}(Set{T}(), Set{T}())

function add!(buffer::VarConstrBuffer{VC}, vc::VC) where {VC<:AbstractVarConstr}
    !get_cur_is_explicit(vc) && return # cannot modify implicit vcs
    id = getid(vc)
    !(id in buffer.removed) && push!(buffer.added, id)
    delete!(buffer.removed, id)
    return
end

function remove!(buffer::VarConstrBuffer{VC}, vc::VC) where {VC<:AbstractVarConstr}
    !get_cur_is_explicit(vc) && return # cannot modify implicit vcs
    id = getid(vc)
    !(id in buffer.added) && push!(buffer.removed, id)
    delete!(buffer.added, id)
    return
end

"""
    FormulationBuffer()

A `FormulationBuffer` stores all changes done to a `Formulation` `f` since last call to `optimize!(f)`.
When function `optimize!(f)` is called, the moi_optimizer is synched with all changes in FormulationBuffer

When `f` is modified, such modification should not be passed directly to its optimizer, but instead should be passed to `f.buffer`.

The concerned modificatios are:
1. Cost change in a variable
2. Bound change in a variable
3. Right-hand side change in a Constraint
4. Variable is removed
5. Variable is added
6. Constraint is removed
7. Constraint is added
8. Coefficient in the matrix is modified (reset)
"""
mutable struct FormulationBuffer
    changed_cost::Set{Id{Variable}}
    changed_bound::Set{Id{Variable}}
    changed_kind::Set{Id{Variable}}
    changed_rhs::Set{Id{Constraint}}
    var_buffer::VarConstrBuffer{Variable}
    constr_buffer::VarConstrBuffer{Constraint}
    reset_coeffs::Dict{Pair{Id{Constraint},Id{Variable}},Float64}
    #reset_partial_sols::Dict{Pair{Id{Variable},Id{Variable}},Float64}
end
"""
    FormulationBuffer()

Constructs an empty `FormulationBuffer`.
"""
FormulationBuffer() = FormulationBuffer(
    Set{Id{Variable}}(), Set{Id{Variable}}(), Set{Id{Variable}}(),
    Set{Id{Constraint}}(), VarConstrBuffer{Variable}(),
    VarConstrBuffer{Constraint}(),
    Dict{Pair{Id{Constraint},Id{Variable}},Float64}()
    # , Dict{Pair{Id{Variable},Id{Variable}},Float64}()
)

add!(b::FormulationBuffer, var::Variable) = add!(b.var_buffer, var)
add!(b::FormulationBuffer, constr::Constraint) = add!(b.constr_buffer, constr)

remove!(buffer::FormulationBuffer, var::Variable) = remove!(
    buffer.var_buffer, var
)

remove!(buffer::FormulationBuffer, constr::Constraint) = remove!(
    buffer.constr_buffer, constr
)

function change_cost!(buffer::FormulationBuffer, v::Variable)
    !get_cur_is_explicit(v) && return
    push!(buffer.changed_cost, getid(v))
    return
end

function change_bound!(buffer::FormulationBuffer, v::Variable)
    !get_cur_is_explicit(v) && return
    push!(buffer.changed_bound, getid(v))
    return
end

function change_kind!(buffer::FormulationBuffer, v::Variable)
    !get_cur_is_explicit(v) && return
    push!(buffer.changed_kind, getid(v))
    return
end

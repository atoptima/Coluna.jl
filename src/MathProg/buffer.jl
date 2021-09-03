"""
A `VarConstrBuffer{I}` stores the ids of type `I` of the variables, constraints or 
single variable constraints that will be added and removed from a formulation.
"""
mutable struct VarConstrBuffer{I<:Id}
    added::Set{I}
    removed::Set{I}
end

VarConstrBuffer{I}() where {I<:Id} = VarConstrBuffer{I}(Set{I}(), Set{I}())

function add!(buffer::VarConstrBuffer{I}, id::I) where {I<:Id}
    if id ∉ buffer.removed
        push!(buffer.added, id)
    else
        delete!(buffer.removed, id)
    end
    return
end

function remove!(buffer::VarConstrBuffer{I}, id::I) where {I<:Id}
    if id ∉ buffer.added
        push!(buffer.removed, id)
    else
        delete!(buffer.added, id)
    end
    return
end

"""
A `FormulationBuffer` stores all changes done to a formulation since last call to `sync_solver!`.
When function `sync_solver!` is called, the optimizer is synched with all changes in FormulationBuffer

**Warning** : You should not pass formulation changes straight to its optimizer.
Changes must be always buffered.
"""
mutable struct FormulationBuffer
    changed_obj_sense::Bool # sense of the objective function
    changed_obj_const::Bool # constant in the objective function
    changed_cost::Set{VarId} # cost of a variable
    changed_bound::Set{VarId} # bound of a variable
    changed_var_kind::Set{VarId} # kind of a variable
    changed_rhs::Set{ConstrId} # rhs and sense of a constraint
    var_buffer::VarConstrBuffer{VarId} # variable added or removed
    constr_buffer::VarConstrBuffer{ConstrId} # constraint added or removed
    singlevarconstr_buffer::VarConstrBuffer{SingleVarConstrId} # single var constraint added or removed
    reset_coeffs::Dict{Pair{ConstrId,VarId},Float64} # coefficient of the matrix changed
end

FormulationBuffer() = FormulationBuffer(
    false, false, Set{VarId}(), Set{VarId}(), Set{VarId}(), Set{ConstrId}(),
    VarConstrBuffer{VarId}(), VarConstrBuffer{ConstrId}(), 
    VarConstrBuffer{SingleVarConstrId}(), Dict{Pair{ConstrId,VarId},Float64}()
)

add!(b::FormulationBuffer, varid::VarId) = add!(b.var_buffer, varid)
add!(b::FormulationBuffer, constrid::ConstrId) = add!(b.constr_buffer, constrid)

# Since there is no efficient way to remove changes done to the coefficient matrix,
# we propagate them if the variable is active and explicit
function remove!(buffer::FormulationBuffer, varid::VarId)
    remove!(buffer.var_buffer, varid)
    delete!(buffer.changed_cost, varid)
    delete!(buffer.changed_bound, varid)
    delete!(buffer.changed_var_kind, varid)
    return
end

# Since there is no efficient way to remove changes done to the coefficient matrix,
# we propagate them if the constraint is active and explicit
function remove!(buffer::FormulationBuffer, constrid::ConstrId)
    remove!(buffer.constr_buffer, constrid)
    delete!(buffer.changed_rhs, constrid)
    return
end

function change_rhs!(buffer::FormulationBuffer, constrid::ConstrId)
    push!(buffer.changed_rhs, constrid)
    return
end

function change_cost!(buffer::FormulationBuffer, varid::VarId)
    push!(buffer.changed_cost, varid)
    return
end

function change_bound!(buffer::FormulationBuffer, varid::VarId)
    push!(buffer.changed_bound, varid)
    return
end

function change_kind!(buffer::FormulationBuffer, varid::VarId)
    push!(buffer.changed_var_kind, varid)
    return
end

function set_matrix_coeff!(
    buffer::FormulationBuffer, varid::VarId, constrid::ConstrId, new_coeff::Float64
)
    buffer.reset_coeffs[Pair(constrid, varid)] = new_coeff
    return
end

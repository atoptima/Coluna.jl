"""
A `VarConstrBuffer{I,VC}` stores the ids of type `I` of the variables or constraints
that will be added and removed from a formulation.
"""
mutable struct VarConstrBuffer{I<:Id,VC<:AbstractVarConstr}
    added::Set{I}
    removed::Set{I}
    definitive_deletion::Dict{I,VC}
end

function VarConstrBuffer{I,VC}() where {I<:Id,VC<:AbstractVarConstr}
    return VarConstrBuffer(Set{I}(), Set{I}(), Dict{I,VC}())
end

function Base.isequal(a::VarConstrBuffer{I,VC}, b::VarConstrBuffer{I,VC}) where {I,VC}
    return isequal(a.added, b.added) && isequal(a.removed, b.removed)
end

function add!(buffer::VarConstrBuffer{I,VC}, id::I) where {I<:Id,VC}
    if id ∉ buffer.removed
        push!(buffer.added, id)
    else
        delete!(buffer.removed, id)
    end
    return
end

function remove!(buffer::VarConstrBuffer{I,VC}, id::I) where {I<:Id,VC}
    if id ∉ buffer.added
        push!(buffer.removed, id)
    else
        delete!(buffer.added, id)
    end
    return
end

function definitive_deletion!(buffer::VarConstrBuffer{I,VC}, elem::VC) where {I<:Id,VC}
    id = getid(elem)
    if id ∉ buffer.added
        push!(buffer.removed, id)
        buffer.definitive_deletion[id] = elem
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
    var_buffer::VarConstrBuffer{VarId, Variable} # variable added or removed
    constr_buffer::VarConstrBuffer{ConstrId, Constraint} # constraint added or removed
    reset_coeffs::Dict{Pair{ConstrId,VarId},Float64} # coefficient of the matrix changed
end

FormulationBuffer() = FormulationBuffer(
    false, false, Set{VarId}(), Set{VarId}(), Set{VarId}(), Set{ConstrId}(),
    VarConstrBuffer{VarId, Variable}(), VarConstrBuffer{ConstrId, Constraint}(), 
    Dict{Pair{ConstrId,VarId},Float64}()
)

function empty!(buffer::FormulationBuffer)
    buffer.changed_obj_sense = false
    buffer.changed_obj_const = false
    buffer.changed_cost = Set{VarId}()
    buffer.changed_bound = Set{VarId}()
    buffer.changed_var_kind = Set{VarId}()
    buffer.changed_rhs = Set{ConstrId}()
    buffer.var_buffer = VarConstrBuffer{VarId, Variable}()
    buffer.constr_buffer = VarConstrBuffer{ConstrId, Constraint}()
    buffer.reset_coeffs = Dict{Pair{ConstrId,VarId},Float64}()
end

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

# Use definitive deletion when you delete the variable from the formulation,
# Otherwise, the variable object is garbage collected so we can't retrieve the
# other constraints attached to the variable anymore. 
# definitive_deletion! keeps the object until deletion is performed in the subsolver.
function definitive_deletion!(buffer::FormulationBuffer, var::Variable)
    varid = getid(var)
    definitive_deletion!(buffer.var_buffer, var)
    delete!(buffer.changed_cost, varid)
    delete!(buffer.changed_bound, varid)
    delete!(buffer.changed_var_kind, varid)
    return
end

# Since there is no efficient way to remove changes done to the coefficient matrix,
# we propagate them if and only if the constraint is active and explicit
function remove!(buffer::FormulationBuffer, constrid::ConstrId)
    remove!(buffer.constr_buffer, constrid)
    delete!(buffer.changed_rhs, constrid)
    return
end

# Same as definitive_deletion! of a variable.
function definitive_deletion!(buffer::FormulationBuffer, constr::Constraint)
    definitive_deletion!(buffer.constr_buffer, constr)
    delete!(buffer.changed_rhs, getid(constr))
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

"""
A `VarConstrBuffer{I,VC}` stores the ids of type `I` of the variables or constraints
that will be added and removed from a formulation.
"""
mutable struct VarConstrBuffer{I,VC}
    added::Set{I}
    removed::Set{I}
    definitive_deletion::Dict{I,VC}
end

function VarConstrBuffer{I,VC}() where {I,VC}
    return VarConstrBuffer(Set{I}(), Set{I}(), Dict{I,VC}())
end

function Base.isequal(a::VarConstrBuffer{I,VC}, b::VarConstrBuffer{I,VC}) where {I,VC}
    return isequal(a.added, b.added) && isequal(a.removed, b.removed)
end

function add!(buffer::VarConstrBuffer{I,VC}, id::I) where {I,VC}
    if id ∉ buffer.removed
        push!(buffer.added, id)
    else
        delete!(buffer.removed, id)
    end
    return
end

function remove!(buffer::VarConstrBuffer{I,VC}, id::I) where {I,VC}
    if id ∉ buffer.added
        push!(buffer.removed, id)
    else
        delete!(buffer.added, id)
    end
    return
end

function definitive_deletion!(buffer::VarConstrBuffer{I,VC}, elem::VC) where {I,VC}
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
mutable struct FormulationBuffer{Vi,V,Ci,C}
    changed_obj_sense::Bool # sense of the objective function
    changed_cost::Set{Vi} # cost of a variable
    changed_bound::Set{Vi} # bound of a variable
    changed_var_kind::Set{Vi} # kind of a variable
    changed_rhs::Set{Ci} # rhs and sense of a constraint
    var_buffer::VarConstrBuffer{Vi,V} # variable added or removed
    constr_buffer::VarConstrBuffer{Ci,C} # constraint added or removed
    reset_coeffs::Dict{Pair{Ci,Vi},Float64} # coefficient of the matrix changed
end

FormulationBuffer{Vi,V,Ci,C}() where {Vi,V,Ci,C} = FormulationBuffer(
    false, Set{Vi}(), Set{Vi}(), Set{Vi}(), Set{Ci}(),
    VarConstrBuffer{Vi, V}(), VarConstrBuffer{Ci, C}(), 
    Dict{Pair{Ci,Vi},Float64}()
)

function empty!(buffer::FormulationBuffer{Vi,V,Ci,C}) where {Vi,V,Ci,C}
    buffer.changed_obj_sense = false
    buffer.changed_cost = Set{Vi}()
    buffer.changed_bound = Set{Vi}()
    buffer.changed_var_kind = Set{Vi}()
    buffer.changed_rhs = Set{Ci}()
    buffer.var_buffer = VarConstrBuffer{Vi,V}()
    buffer.constr_buffer = VarConstrBuffer{Ci,C}()
    buffer.reset_coeffs = Dict{Pair{Ci,Vi},Float64}()
end
add!(b::FormulationBuffer{Vi,V,Ci,C}, varid::Vi) where {Vi,V,Ci,C} = add!(b.var_buffer, varid)
add!(b::FormulationBuffer{Vi,V,Ci,C}, constrid::Ci) where {Vi,V,Ci,C} = add!(b.constr_buffer, constrid)

# Since there is no efficient way to remove changes done to the coefficient matrix,
# we propagate them if the variable is active and explicit
function remove!(buffer::FormulationBuffer{Vi,V,Ci,C}, varid::Vi) where {Vi,V,Ci,C}
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
function definitive_deletion!(buffer::FormulationBuffer{Vi,V,Ci,C}, var::V) where {Vi,V,Ci,C}
    varid = getid(var)
    definitive_deletion!(buffer.var_buffer, var)
    delete!(buffer.changed_cost, varid)
    delete!(buffer.changed_bound, varid)
    delete!(buffer.changed_var_kind, varid)
    return
end

# Since there is no efficient way to remove changes done to the coefficient matrix,
# we propagate them if and only if the constraint is active and explicit
function remove!(buffer::FormulationBuffer{Vi,V,Ci,C}, constrid::Ci) where {Vi,V,Ci,C}
    remove!(buffer.constr_buffer, constrid)
    delete!(buffer.changed_rhs, constrid)
    return
end

# Same as definitive_deletion! of a variable.
function definitive_deletion!(buffer::FormulationBuffer{Vi,V,Ci,C}, constr::C) where {Vi,V,Ci,C}
    definitive_deletion!(buffer.constr_buffer, constr)
    delete!(buffer.changed_rhs, getid(constr))
    return
end

function change_rhs!(buffer::FormulationBuffer{Vi,V,Ci,C}, constrid::Ci) where {Vi,V,Ci,C}
    push!(buffer.changed_rhs, constrid)
    return
end

function change_cost!(buffer::FormulationBuffer{Vi,V,Ci,C}, varid::Vi) where {Vi,V,Ci,C}
    push!(buffer.changed_cost, varid)
    return
end

function change_bound!(buffer::FormulationBuffer{Vi,V,Ci,C}, varid::Vi) where {Vi,V,Ci,C}
    push!(buffer.changed_bound, varid)
    return
end

function change_kind!(buffer::FormulationBuffer{Vi,V,Ci,C}, varid::Vi) where {Vi,V,Ci,C}
    push!(buffer.changed_var_kind, varid)
    return
end

function change_matrix_coeff!(
    buffer::FormulationBuffer{Vi,V,Ci,C}, constrid::Ci, varid::Vi, new_coeff::Float64
) where {Vi,V,Ci,C}
    buffer.reset_coeffs[Pair(constrid, varid)] = new_coeff
    return
end

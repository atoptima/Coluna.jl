
mutable struct Filter
    used_mask::SparseVector{Bool,Int}
    active_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
    artificial_mask::SparseVector{Bool,Int}
end

Filter() = Filter(spzeros(0), spzeros(0), spzeros(0), spzeros(0))


#function extact_terms
    
#    return
#end

    

struct Memberships
    var_memberships::Dict{VarId, ConstrMembership}
    expression_memberships::Dict{VarId, VarMembership}
    constr_memberships::Dict{ConstrId, VarMembership}
end


function Memberships()
    var_m = Dict{VarId, ConstrMembership}()
    expression_m = Dict{VarId, VarMembership}()
    constr_m = Dict{ConstrId, ConstrMembership}()
    return Memberships(var_m, expression_m, constr_m)
end


hasvar(m::Memberships, uid) = haskey(m.var_memberships, uid)
hasconstr(m::Memberships, uid) = haskey(m.constr_memberships, uid)

function getvarmembership(m::Memberships, uid) 
    hasvar(m, uid) && return m.var_memberships[uid]
    error("Variable $uid not stored in formulation.")
end

function getconstrmembership(m::Memberships, uid) 
    hasconstr(m, uid) && return m.constr_memberships[uid]
    error("Constraint $uid not stored in formulation.")
end

#==
mutable struct Manager{T <: AbstractVarConstr}
    vc_list::SparseVector{Any, Int} #SparseVector{AbstractMoiDef, Int}
    active_mask::SparseVector{Bool,Int}
    inactive_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
    nonstatic_mask::SparseVector{Bool,Int}
end

# getlist(m::Manager{Constraint}) = m.vc_list::SparseVector{MoiConstrDef, Id{Constraint}}
# getlist(m::Manager{Variable}) = m.vc_list::SparseVector{MoiVarDef, Id{Variable}}

Manager(::Type{T}) where {T <: AbstractVarConstr} = Manager{T}(spzeros(0), spzeros(0), spzeros(0))

function get_list(m::Manager, active::Bool, static::Bool)
    if active
        static && return m.vc_list[m.active_mask .& m.static_mask]
        !static && return m.vc_list[m.active_mask .& m.nonstatic_mask]
    end
    static && return  m.vc_list[m.inactive_mask .& m.static_mask]
    return m.vc_list[m.inactive_mask .& m.dynamic_mask]
end

function get_active_list(m::Manager, active::Bool)
    if active
        return m.vc_list[m.active_mask]
    end
    return m.vc_list[m.inactive_mask]
end

function get_static_list(m::Manager, static::Bool)
    if static
        return m.vc_list[m.static_mask]
    end
    return m.vc_list[m.nonstatic_mask]
end

function add_in_manager(m::Manager{T}, elem::T, active::Bool) where {T <: AbstractVarConstr}
    uid = getuid(elem)
    m.vc_list[uid] = elem
    active_mask[uid] = active
    inactive_mask[uid] = !active
    static_mask[uid] = isstatic(elem) 
    nonstatic_mask[uid] = !isstatic(elem) 
    return
end

function remove_from_manager(m::Manager{T}, elem::T) where {T <: AbstractVarConstr}
    uid = getuid(elem)
    deleteat!(m.vc_list, uid)
    deleteat!(m.active_mask, uid)
    deleteat!(m.inactive_mask, uid)
    deleteat!(m.static_mask, uid)
    deleteat!(m.nonstatic_mask, uid)
    return
end

==#

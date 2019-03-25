mutable struct Filter
    used_mask::SparseVector{Bool,Int}
    active_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
    artificial_mask::SparseVector{Bool,Int}
end

Filter() = Filter(spzeros(MAX_SV_ENTRIES), spzeros(MAX_SV_ENTRIES), spzeros(MAX_SV_ENTRIES), spzeros(MAX_SV_ENTRIES))

activemask(f::Filter) = f.used_mask .& f.active_mask
staticmask(f::Filter) = f.used_mask .& f.static_mask
artificalmask(f::Filter) = f.used_mask .& f.artificial_mask
#selectivemask(f::Filter, active::Bool, static::Bool, artificial::Bool) = f.used_mask active ? .& f.active_mask : nothing  static ? .& f.static_mask : nothing  artificial ? .& f.artificial_mask : nothing

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
hasexpression(m::Memberships, uid) = haskey(m.expression_memberships, uid)

function getvarmembership(m::Memberships, uid) 
    hasvar(m, uid) && return m.var_memberships[uid]
    error("Variable $uid not stored in formulation.")
end

function getconstrmembership(m::Memberships, uid) 
    hasconstr(m, uid) && return m.constr_memberships[uid]
    error("Constraint $uid not stored in formulation.")
end

function getexpressionmembership(m::Memberships, uid) 
    hasexpression(m, uid) && return m.expression_memberships[uid]
    error("Expression $uid not stored in formulation.")
end

function add_variable!(m::Memberships, var_uid::VarId)
    hasvar(m, var_uid) && error("Variable with uid $var_uid already registered.")
    m.var_memberships[var_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_variable!(m::Memberships, var_uid::VarId, membership::SparseVector)
    hasvar(m, var_uid) && error("Variable with uid $var_uid already registered.")
    m.var_memberships[var_uid] = membership
    constr_uids, vals = findnz(membership)
    for j in 1:length(constr_uids)
        !hasvar(m, constr_uids[j]) && error("Constr with uid $(constr_uids[j]) not registered in Memberships.")
        m.constr_memberships[constr_uids[j]][var_uid] = vals[j]
    end
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId)
    hasconstr(m, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    m.constr_memberships[constr_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId, membership::SparseVector) 
    hasconstr(m, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    m.constr_memberships[constr_uid] = membership
    var_uids, vals = findnz(membership)
    for j in 1:length(var_uids)
        !hasvar(m, var_uids[j]) && error("Variable with uid $(var_uids[j]) not registered in Memberships.")
        m.var_memberships[var_uids[j]][constr_uid] = vals[j]
    end
    return
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

struct Membership{T <: AbstractVarConstr}
    member_coef_map::SparseVector{Float64, Int}
end

function Membership(::Type{T}) where {T <: AbstractVarConstr}
    return Membership{T}(spzeros(Float64, MAX_SV_ENTRIES))
end

function get_coeff(m::Membership, id::Int)
    return m.member_coef_map[id]
end

mutable struct Manager{T <: AbstractVarConstr}
    vc_list::SparseVector{Any, Int} #SparseVector{AbstractMoiDef, Int}
    active_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
end

# getlist(m::Manager{Constraint}) = m.vc_list::SparseVector{MoiConstrDef, Id{Constraint}}
# getlist(m::Manager{Variable}) = m.vc_list::SparseVector{MoiVarDef, Id{Variable}}

Manager(::Type{T}) where {T <: AbstractVarConstr} = Manager{T}(spzeros(0), spzeros(0), spzeros(0))

function get_list(m::Manager, active::Bool, static::Bool)
    if active
        static && return m.vc_list[m.active_mask .& m.static_mask]
        !static && return m.vc_list[m.active_mask .& !m.static_mask]
    end
    static && return  m.vc_list[!m.active_mask .& m.static_mask]
    return m.vc_list[!m.active_mask .& m.dynamic_mask]
end

function get_active_list(m::Manager, active::Bool)
    if active
        return m.vc_list[m.active_mask]
    end
    return m.vc_list[!m.active_mask]
end

function get_static_list(m::Manager, static::Bool)
    if static
        return m.vc_list[m.static_mask]
    end
    return m.vc_list[!m.static_mask]
end

function add_in_manager(m::Manager{T}, elem::T, active::Bool) where {T <: AbstractVarConstr}
    uid = getuid(elem)
    m.vc_list[uid] = elem
    active_mask[uid] = active
    static_mask[uid] = isstatic(elem) 
    return
end

function remove_from_manager(m::Manager{T}, elem::T) where {T <: AbstractVarConstr}
    uid = getuid(elem)
    deleteat!(m.vc_list, uid)
    deleteat!(m.active_mask, uid)
    deleteat!(m.static_mask, uid)
    return
end


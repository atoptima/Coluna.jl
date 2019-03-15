struct Membership{T <: AbstractVarConstr}
    member_coef_map::SparseVector{Float64,Int}
end

function get_coeff(m::Membership{T}, id::Id{T}) where {T <: AbstractVarConstr}
    return m.member_coef_map[id.id]
end

mutable struct Manager{T <: AbstractVarConstr}
    active_static_list::SparseVector{Int,Int}
    active_dynamic_list::SparseVector{Int,Int}
    unsuitable_static_list::SparseVector{Int,Int}
    unsuitable_dynamic_list::SparseVector{Int,Int}
end

Manager{T}() where {T <: AbstractVarConstr} = Manager{T}(spzeros(0), spzeros(0), spzeros(0), spzeros(0))

function get_list(m::Manager, active::Bool, static::Bool)
    if active
        static && return m.active_static_list
        !static && return m.active_dynamic_list
    end
    static && return m.unsuitable_static_list
    return m.unsuitable_dynamic_list
end

function add_in_manager(m::Manager{T}, elem::T) where {T <: AbstractVarConstr}
    list = get_list(m, elem.flag == 'd', elem.status == 's')
    list[elem.uid] = elem.moi_id
    return
end

function remove_from_manager(m::Manager{T}, elem::T) where {T <: AbstractVarConstr}
    list = get_list(m, elem.flag == 'd', elem.status == 's')
    deleteat!(list, elem.uid)
    return
end

struct Table{T <: AbstractVarConstr}
    elem_to_moi_ref::Dict{Any, Any}
end

Table{T}() where {T <: AbstractVarConstr} = Table{T}(Dict())



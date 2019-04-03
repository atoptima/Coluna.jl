# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:AbstractVarConstrId,
#          <:Pair{<:AbstractVarConstr, <:AbstractVarConstrInfo}})::Bool

struct Manager{I <: Id,T}  <: AbstractManager
    members::Dict{I,T}
end

function Manager{I <: Id, T}()
    return Manager{I <: Id, T}(Dict{I,T}())
end

function Manager(VCtype::Type{<:AbstractVarConstr}, ValType::DataType)
    return Manager{idtype(VCtype), ValType}(Dict{idtype(VCtype),ValType}())
end


#Manager(T::Type{<:AbstractVarConstr}) = Manager(T, T)

function set!(m::Manager{I,T}, id::I, val::T) where {I <: Id, T}
    m.members[id] = val
    return
end

function add!(m::Manager{I,T}, id::I, val::T) where {I <: Id, T <: Real}
    if !haskey(m.members, id) 
        m.members[id] = val
    else
        m.members[id] += val
    end
    return
end

#getvarconstr(e::Pair{Id,VC}) where {Id, VC} = e[2]

getmembers(m::Manager) = m.members

has(m::Manager, id::Id) = haskey(m.members, id)

get(m::Manager, id::Id) = m.members[id]

#get(m::Manager, uid::Int) = m.members[Id(uid)]

getids(m::Manager) = collect(keys(m.members))

iterate(m::Manager) = iterate(m.members)

iterate(m::Manager, state) = iterate(m.members, state)

length(m::Manager) = length(m.members)

getindex(m::Manager, elements) = getindex(m.members, elements)

lastindex(m::Manager) = lastindex(m.members)

Base.filter(f::Function, m::Manager) = filter(f, m.members)

clone(m::Manager{T,U}) where {T,U} = Membership{T,U}(copy(m.members))

getinfo(e::Pair{I,T})  where {I <: Id, T} = e[1].info


get_subset(m::Manager{I,T}, Duty::Type{<:AbstractConstrDuty}, stat::Status) where {I <: AbstractVarConstrInfo, T} = filter(e -> dutytype(getinfo(e)) == Duty && getinfo(e).status == stat, m.members)

get_subset(m::Manager{I,T}, Duty::Type{<:AbstractConstrDuty}) where {I <: AbstractVarConstrInfo, T} = filter(e -> dutytype(getinfo(e)) == Duty, m.members)


function Base.show(io::IO, m::Manager)
    println(io, typeof(m), ":")
    for e in m.members
        println(io, "  ", e)
    end
    return

end

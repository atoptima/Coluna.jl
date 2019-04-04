# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:Id, T})::Bool

_active_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getinfo(id_val[1])) == Active

_active_MspVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getinfo(id_val[1])) == Active &&
    getduty(getinfo(id_val[1])) == MastRepPricingSpVar

_active_pricingSpVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getinfo(id_val[1])) == Active &&
    getduty(getinfo(id_val[1])) == PricingSpVar

function _explicit_(id_val::Pair{I,T}) where {I<:Id,T}
    d = getduty(getinfo(id_val[1]))
    return (d != MastRepPricingSpVar && d != MastRepPricingSetupSpVar
            && d != MastRepBendSpVar)
end

struct Manager{I <: Id,T}  <: AbstractManager
    members::Dict{I,T}
end

function Manager(VCtype::Type{<:AbstractVarConstr}, ValType::DataType)
    return Manager{idtype(VCtype), ValType}(Dict{idtype(VCtype),ValType}())
end

function Manager(VCtype::Type{<:AbstractVarConstr})
    return Manager{idtype(VCtype), VCtype}(Dict{idtype(VCtype),VCtype}())
end

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

getinfo(e::Pair{I,T}) where {I <: Id, T} = getinfo(e[1])

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

Base.filter(f::Function, m::Manager) = typeof(m)(filter(f, m.members))



clone(m::Manager{I,T}) where {I,T} = Membership{I,T}(copy(m.members))

#get_subset(m::Manager{I,T}, Duty::Type{<:AbstractDuty}, stat::Status) where {I <: Id, T} = filter(e -> getduty(getinfo(e)) isa Duty && getinfo(e).cur_status == stat, m.members)

#get_subset(m::Manager{I,T}, Duty::Type{<:AbstractDuty}) where {I <: Id, T} = filter(e -> getduty(getinfo(e)) isa Duty, m.members)

#get_subset(m::Manager{I,T}, stat::Status) where {I <: Id, T} = filter(e -> getinfo(e).cur_status == stat, m.members)

function Base.show(io::IO, m::Manager)
    println(io, typeof(m), ":")
    for e in m.members
        println(io, "  ", e)
    end
    return

end

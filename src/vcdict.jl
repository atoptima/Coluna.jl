# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:Id, T})::Bool

_active_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active

_active_MspVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active &&
    getduty(getstate(id_val[1])) == MastRepPricingSpVar

_active_pricingSpVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active &&
    getduty(getstate(id_val[1])) == PricingSpVar

function _explicit_(id_val::Pair{I,T}) where {I<:Id,T}
    d = getduty(getstate(id_val[1]))
    return (d != MastRepPricingSpVar && d != MastRepPricingSetupSpVar
            && d != MastRepBendSpVar)
end

struct PerIdDict{S <: AbstractState,T}
    members::Dict{Id{S},T}
end
PerIdDict{S,T}() where {S,T} = PerIdDict{S,T}(Dict{Id{S},T}())

function set!(d::PerIdDict{S,T}, id::Id{S}, val::T) where {S<:AbstractState,T}
    d.members[id] = val
    return
end

function add!(d::PerIdDict{S,T}, id::Id{S}, val::T) where {S<:AbstractState,T<:Real}
    if !haskey(d.members, id) 
        d.members[id] = val
    else
        d.members[id] += val
    end
    return
end

function delete!(d::PerIdDict{S,T}, id::Id{S}, val::T) where {S<:AbstractState,T<:Real}
    if haskey(d.members, id)
        deleteat!(d.members, id)
    end
    return
end



getinfo(e::Pair{Id{S},T}) where {S<:AbstractState,T} = getinfo(e[1])

getmembers(d::PerIdDict) = d.members

haskey(d::PerIdDict, id::Id) = haskey(d.members, id)

get(d::PerIdDict, id::Id) = d.members[id]

#get(d::PerIdDict, uid::Int) = d.members[Id(uid)]
Base.getkey(d::PerIdDict, i::Id, default) = getkey(d.members, i, default)

getids(d::PerIdDict) = collect(keys(d.members))

iterate(d::PerIdDict) = iterate(d.members)

iterate(d::PerIdDict, state) = iterate(d.members, state)

length(d::PerIdDict) = length(d.members)

getindex(d::PerIdDict, elements) = getindex(d.members, elements)

copy(d::PerIdDict{S,T}) where {S<:AbstractState,T} = PerIdDict{S,T}(copy(d.members))

lastindex(d::PerIdDict) = lastindex(d.members)

Base.filter(f::Function, d::PerIdDict) = typeof(d)(filter(f, d.members))

function Base.show(io::IO, d::PerIdDict)
    println(io, typeof(d), ":")
    for e in d.members
        println(io, "  ", e)
    end
    return

end

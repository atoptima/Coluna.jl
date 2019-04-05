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

function Base.delete!(m::PerIdDict{S,T}, id::Id{S}) where {S <: AbstractState,T}
    delete!(m.members, id)
    return
end

function Base.delete!(m::PerIdDict{S,T}, id::Vector{Id}) where {S <: AbstractState, T}
    delete!(m.members, id)
    return
end

function Base.setindex!(m::PerIdDict{S,T}, val::T, id::Id{S}) where {S <: AbstractState, T}
    return Base.setindex!(m.members, val, id)
end

getinfo(e::Pair{Id{S},T}) where {S<:AbstractState,T} = getinfo(e[1])

getmembers(d::PerIdDict) = d.members

haskey(d::PerIdDict, id::Id) = haskey(d.members, id)

get(d::PerIdDict, id::Id) = d.members[id]

#getid(d::PerIdDict, id::Id) = getkey(d.members, id)

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

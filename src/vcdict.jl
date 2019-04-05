struct PerIdDict{S <: AbstractState,T}
    members::Dict{Id{S},T}
end

PerIdDict{S,T}() where {S,T} = PerIdDict{S,T}(Dict{Id{S},T}())

# Overload of Base methods to use PerIdDict like a Dict
function Base.getindex(d::PerIdDict{S,T}, id::Id{S}) where {S<:AbstractState, T}
    Base.getindex(d.members, id)
end

function Base.setindex!(d::PerIdDict{S,T}, val::T, id::Id{S}) where {S<:AbstractState,T}
    Base.setindex!(d.members, val, id)
end

function Base.delete!(d::PerIdDict{S,T}, id::Id{S}) where {S<:AbstractState,T}
    Base.delete!(d.members, id)
end

function Base.delete!(d::PerIdDict{S,T}, id::Vector{Id}) where {S<:AbstractState,T}
    Base.delete!(d.members, id)
end

function Base.getkey(d::PerIdDict{S,T}, i::Id{S}, default) where {S<:AbstractState,T}
    Base.getkey(d.members, i, default)
end

function Base.get(d::PerIdDict{S,T}, i::Id{S}, default) where {S<:AbstractState,T}
    Base.get(d.members, i, default)
end

function Base.copy(d::PerIdDict{S,T}) where {S<:AbstractState,T}
    PerIdDict{S,T}(copy(d.members))
end

function Base.haskey(d::PerIdDict{S,T}, id::Id{S}) where {S<:AbstractState,T}
    Base.haskey(d.members, id)
end

Base.keys(d::PerIdDict) = Base.keys(d.members)
Base.filter(f::Function, d::D) where {D<:PerIdDict} = D(filter(f, d.members))

function Base.show(io::IO, d::PerIdDict)
    println(io, typeof(d), ":")
    for e in d.members
        println(io, "  ", e)
    end
    return
end

# Methods to iterate over a PerIdDict
iterate(d::PerIdDict) = iterate(d.members)
iterate(d::PerIdDict, state) = iterate(d.members, state)
length(d::PerIdDict) = length(d.members)
lastindex(d::PerIdDict) = lastindex(d.members)

####

getinfo(e::Pair{Id{S},T}) where {S<:AbstractState,T} = getinfo(e[1])
getids(d::PerIdDict) = collect(keys(d.members))
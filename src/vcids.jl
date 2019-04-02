struct Id{T <: AbstractVarConstr} <: AbstractVarConstrId
    uid::Int
    info::AbstractVarConstrInfo
end

Id(T::Type{<: AbstractVarConstr}, i::Int) = Id{T}(i, infotype(T)())

Id(id::Id{T}) where {T} = Id{T}(id.uid, id.info)

# Id(uid::Int) = Id(uid, nothing)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)
Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::AbstractVarConstrId) = id.uid
getinfo(id::AbstractVarConstrId) = id.info

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id(", getuid(id), ")")
end

getinfo(Pair{Id, Float64}) = Id.info

getinfo(Id) = Id.info



struct Id{T <: AbstractVarConstr, VcInfo <: AbstractVarConstrInfo} <: AbstractVarConstrId
    uid::Int
    info::VcInfo
end

#Id(T::Type{<: AbstractVarConstr}, i::Int) = Id{T}(i, infotype(T)())

Id{T <: AbstractVarConstr}  = Id{T, infotype(T)}

Id(id::Id{T}) where {T} = Id{T}(id.uid, id.info)

function Id(uid::Int, info::T) where {T <: AbstractVarConstrInfo}
    return Id{vctype(T), T}(uid, info)
end

# Id(uid::Int) = Id(uid, nothing)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)
Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::AbstractVarConstrId) = id.uid
getinfo(id::AbstractVarConstrId) = id.info
#getinfo(p::Pair{Id, Float64}) = p.info

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id(", getuid(id), ")")
end


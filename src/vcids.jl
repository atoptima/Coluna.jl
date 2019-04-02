struct Id{MoiIndex} <: AbstractVarConstrId # <: MoiVarConstrIndex} <: AbstractVarConstrId
    uid::Int # coluna ref
    index::MoiIndex # moi ref
end

Id(T::Type{<: AbstractVarConstr}, i::Int) = Id{indextype(T)}(i, nothing)

Id(id::Id{MoiIndex}) = Id{MoiIndex}(id.uid, nothing)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(hash(a), hash(b)) # why on hashes ?
Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::AbstractVarConstrId) = id.uid
get_moi_index(id::AbstractVarConstrId) = id.index

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id(", getuid(id), ")")
end


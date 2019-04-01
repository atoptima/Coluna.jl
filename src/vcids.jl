struct Id{MoiIndex} <: AbstractVarConstrId # <: MoiVarConstrIndex} <: AbstractVarConstrId
    uid::Int # coluna ref
    index::MoiIndex # moi ref
end

Id(T::Type{<: AbstractVarConstr}, i::Int) = Id{indextype{T}}(i, nothing)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(hash(a), hash(b))

getuid(id::AbstractVarConstrId) = id.uid
getindex(id::AbstractVarConstrId) = id.index

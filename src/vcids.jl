struct Id{MoiIndex <: MoiVarConstrIndex} <: AbstractVarConstrId
    uid::Int # coluna ref
    index::MoiIndex # moi ref
end

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(hash(a), hash(b))

getuid(id::AbstractVarConstrId) = id.uid
getindex(id::AbstractVarConstrId) = id.index

Id(::Type{Variable}) = Id(-1, MoiVarIndex(-1))
Id(::Type{Constraint}) = Id(-1, MoiConstrIndex(-1))

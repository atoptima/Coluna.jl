struct Id{MoiIndex <: MoiVarConstrIndex} <: AbstractVarConstrId
    uid::Int # coluna ref
    index::MoiIndex # moi ref
end

idtype(::Type{Variable}) = Id{MoiVarIndex}
idtype(::Type{Constraint}) = Id{MoiConstrIndex}

Id(T::Type{Variable}) = Id(-1, idtype(T)(-1))

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.isequal(a::Id, b::Id) = Base.isequal(hash(a), hash(b))

getuid(id::AbstractVarConstrId) = id.uid
getindex(id::AbstractVarConstrId) = id.index

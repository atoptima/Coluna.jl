struct VcId{MoiIndex <: MoiVarConstrIndex} <: AbstractVarConstrId
    uid::Int # coluna ref
    index::MoiIndex # moi ref
end

Base.hash(a::VcId, h::UInt) = hash(a.uid, h)
Base.isequal(a::VcId, b::VcId) = Base.isequal(hash(a), hash(b))

getuid(id::AbstractVarConstrId) = id.uid
getindex(id::AbstractVarConstrId) = id.index

VcId(::Type{Variable}) = VcId(-1, MoiVarIndex(-1))
VcId(::Type{Constraint}) = VcId(-1, MoiVarIndex(-1))

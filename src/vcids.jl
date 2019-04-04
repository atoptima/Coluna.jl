mutable struct Id{VcState <: AbstractState} #<: AbstractVarConstrId
    uid::Int
    state::VcState
end

idtype(::Type{<: Variable}) = Id{VarState}
idtype(::Type{<: Constraint}) = Id{ConstrState}

#Id(T::Type{<: AbstractVarConstr}, i::Int) = Id{T}(i, statetype(T)())

# Id{T <: AbstractVarConstr} = Id{T, statetype(T)} # Default constructor should be enough

Id(id::Id{T}) where {T} = Id{T}(id.uid, id.state)

# Id(uid::Int) = Id(uid, nothing)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)

Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)

Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::Id) = id.uid

getstate(id::Id) = id.state
setstate!(id::Id, s::AbstractState) = id.state = s

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id{$T}(", getuid(id), ")")
end


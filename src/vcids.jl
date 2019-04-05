mutable struct Id{VcState <: AbstractState} #<: AbstractVarConstrId
    uid::Int
    state::VcState
end
Id{S}() where{S<:AbstractState} = Id{S}(-1,S())
Id{S}(i::Int) where{S<:AbstractState} = Id{S}(i,S())

idtype(::Type{<: Variable}) = Id{VarState}
idtype(::Type{<: Constraint}) = Id{ConstrState}

Base.hash(a::Id, h::UInt) = hash(a.uid, h)

Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)

Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::Id) = id.uid

getstate(id::Id) = id.state
setstate!(id::Id, s::AbstractState) = id.state = s

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id{$T}(", getuid(id), ")")
end


struct Id{VcState <: AbstractState} #<: AbstractVarConstrId
    uid::Int
    state::VcState
end

function Id(uid::Int, Duty::Type{<: AbstractDuty}, vc::VC) where{VC <: AbstractVarConstr} 
    return Id{statetype(VC)}(uid, statetype(VC)(Duty, vc))
end

Id{S}(i::Int) where{S<:AbstractState} = Id{S}(i,S())

Id(VC::Type{<:AbstractVarConstr}) = Id{S}(-1,S())

Id{S}() where{S<:AbstractState} = Id{S}(-1,S())

idtype(::Type{<: Variable}) = Id{VarState}

idtype(::Type{<: Constraint}) = Id{ConstrState}

Base.hash(a::Id, h::UInt) = hash(a.uid, h)

Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)

Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::Id) = id.uid

getstate(id::Id) = id.state


function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id{$T}(", getuid(id), ",", getstate(id).duty, ")")
end


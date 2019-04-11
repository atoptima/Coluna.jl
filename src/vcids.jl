struct Id{VC <: AbstractVarConstr}
    uid::Int # -> id in form
    form_uid::Int
    # uid::Int
end
Id{VC}(uid::Int) where {VC} = Id{VC}(uid, -1)
Id(id::Id{VC}, form_uid::Int) where {VC} = Id{VC}(id.uid, form_uid)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)

Base.isequal(a::Id, b::Id) = Base.isequal(a.uid, b.uid)

Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)

getuid(id::Id) = id.uid

getformuid(id::Id) = id.form_uid

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id{$T}(", getuid(id), ",", getformuid(id), ")")
end

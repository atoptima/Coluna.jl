"""
    Id{VC <: AbstractVarConstr}

Coluna identifier of a `Variable` or a `Constraint`.

It is composed by the following uids:
1. `proc_uid`: Number of the process where it was generated
2. `form_uid`: uid of the formulation where it was generated
3. `uid`: uid in the formulation where it was generated
"""
struct Id{VC <: AbstractVarConstr}
    uid::Int
    form_uid::Int
    proc_uid::Int
    _hash::Int
end

function _create_hash(uid::Int, form_uid::Int, proc_uid::Int)
    return (
        uid * _globals_.MAX_FORMULATIOS * _globals_.MAX_PROCESSES
        + form_uid * _globals_.MAX_PROCESSES
        + proc_uid
    )
end

"""
    Id{VC}(uid::Int, form_uid::Int) where {VC<:AbstractVarConstr}

Constructs an `Id` of type `VC` with `uid` = uid and `form_uid` = form_uid.
"""
function Id{VC}(uid::Int, form_uid::Int) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(uid, form_uid, proc_uid, _create_hash(uid, form_uid, proc_uid))
end

function Id{VC}(id::Id) where {VC}
    Id{VC}(id.uid, id.form_uid)
end

Base.hash(a::Id, h::UInt) = hash(a._hash, h)
Base.isequal(a::Id, b::Id) = Base.isequal(a._hash, b._hash)
Base.isequal(a::Int, b::Id) = Base.isequal(a, b._hash)
Base.isequal(a::Id, b::Int) = Base.isequal(a._hash, b)
Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)
Base.zero(I::Type{<:Id}) = I(-1, -1, -1, -1) 
getuid(id::Id) = id.uid
getformuid(id::Id) = id.form_uid
getprocuid(id::Id) = id.proc_uid
getsortid(id::Id) = getuid(id) + 1000000 * getformuid(id)

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, T,"#", id._hash)
end

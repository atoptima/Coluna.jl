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

function Id{VC}(uid::Int, form_uid::Int) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(uid, form_uid, proc_uid, _create_hash(uid, form_uid, proc_uid))
end

Base.hash(a::Id, h::UInt) = hash(a._hash, h)
Base.isequal(a::Id, b::Id) = Base.isequal(a._hash, b._hash)
Base.isequal(a::Int, b::Id) = Base.isequal(a, b._hash)
Base.isequal(a::Id, b::Int) = Base.isequal(a._hash, b)
Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)
getuid(id::Id) = id.uid
getformuid(id::Id) = id.form_uid
getprocuid(id::Id) = id.proc_uid

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, "Id(", id._hash, ")")
    # print(io, "Id{$T}(", id._hash, ")")
    # print(io, "Id{$T}(", getuid(id), ",", getformuid(id), ",", getprocuid(id), ")")
end

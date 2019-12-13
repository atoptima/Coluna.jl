"""
    Id{VC <: AbstractVarConstr}

Coluna identifier of a `Variable` or a `Constraint`.

It is composed by the following uids:
1. `uid`: uid in the formulation where it was generated 
2. `origin_form_uid`: uid of the formulation where it was generated 
3. `assigned_form_uid_in_reformulation`: uid of the formulation where it is generated assigned in the reformulation process
4. `proc_uid`: Number of the process where it was generated 
For a origin jump var/constr the origin_form_uid is the jump model while the assigned_form_uid_in_reformulation is the spform for a pure spform and the master for a pure master var. For a added var/constr the origin_form_uid is where is was created : for instance a master column 's orginal formulation  is the subproblem for which it was a solution and is assigned formulation is the master program.Number of the process where it was generated 
"""

    
struct Id{VC <: AbstractVarConstr}
    uid::VcUid 
    origin_form_uid::FormUid
    assigned_form_uid_in_reformulation::FormUid
    proc_uid::ProcessUid
    _hash::Int
end



function _create_hash(uid::Int, origin_form_uid::FormUid, proc_uid::ProcessUid)
    return (
        uid * _globals_.MAX_FORMULATIOS * _globals_.MAX_PROCESSES
        + origin_form_uid * _globals_.MAX_PROCESSES
        + proc_uid
    )
end

"""
    Id{VC}(uid::Int, form_uid::Int) where {VC<:AbstractVarConstr}

Constructs an `Id` of type `VC` with `uid` = uid and `form_uid` = form_uid.
"""
function Id{VC}(uid::Int, origin_form_uid::FormUid, assigned_form_uid::FormUid) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(uid, origin_form_uid, assigned_form_uid, proc_uid, _create_hash(uid, origin_form_uid, proc_uid))
end

function Id{VC}(uid::Int, origin_form_uid::FormUid) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(uid, origin_form_uid, origin_form_uid, proc_uid, _create_hash(uid, origin_form_uid, proc_uid))
end

function Id{VC}(id::Id{VC}, assigned_form_uid_in_reformulation::FormUid) where {VC}
    Id{VC}(id.uid, id.origin_form_uid, assigned_form_uid_in_reformulation, id.proc_uid, id._hash)
end

function Id{VC}(id::Id{VC}) where {VC}
    Id{VC}(id.uid, id.origin_form_uid, id.assigned_form_uid_in_reformulation, id.proc_uid, id._hash)
end

#Id{VC}(id::Id, form::Formulation) where {VC} = Id{VC}(id, getuid(form))

Base.hash(a::Id, h::UInt) = hash(a._hash, h)
Base.isequal(a::Id, b::Id) = Base.isequal(a._hash, b._hash)
Base.isequal(a::Int, b::Id) = Base.isequal(a, b._hash)
Base.isequal(a::Id, b::Int) = Base.isequal(a._hash, b)
Base.isless(a::Id, b::Id) = Base.isless(a.uid, b.uid)
Base.zero(I::Type{<:Id}) = I(-1, -1, -1, -1) 
getuid(id::Id)::VcUid = id.uid
getoriginformuid(id::Id)::FormUid = id.origin_form_uid
getassignedformuid(id::Id)::FormUid = id.assigned_form_uid_in_reformulation
getprocuid(id::Id)::ProcessUid = id.proc_uid
getsortuid(id::Id)::Int = getuid(id) + 1000000 * getoriginformuid(id)

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, T,"#", id._hash)
end

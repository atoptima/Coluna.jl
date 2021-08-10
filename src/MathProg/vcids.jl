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
    duty::Duty{VC}
    uid::Int32
    origin_form_uid::FormId
    assigned_form_uid_in_reformulation::FormId
    proc_uid::Int8
    custom_family_id::Int8
    _hash::Int
end

function _create_hash(uid, origin_form_uid, proc_uid)
    return (
        uid * MAX_NB_FORMULATIONS * MAX_NB_PROCESSES
        + origin_form_uid * MAX_NB_PROCESSES
        + proc_uid
    )
end

function Id{VC}(duty::Duty{VC}, uid, origin_form_uid, assigned_form_uid, custom_family_id) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(duty, uid, origin_form_uid, assigned_form_uid, proc_uid, custom_family_id, _create_hash(uid, origin_form_uid, proc_uid))
end

function Id{VC}(duty::Duty{VC}, uid, origin_form_uid) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(duty, uid, origin_form_uid, origin_form_uid, proc_uid, -1, _create_hash(uid, origin_form_uid, proc_uid))
end

function Id{VC}(duty::Duty{VC}, uid, origin_form_uid, custom_family_id) where {VC}
    proc_uid = Distributed.myid()
    Id{VC}(duty, uid, origin_form_uid, origin_form_uid, proc_uid, custom_family_id, _create_hash(uid, origin_form_uid, proc_uid))
end

function Id{VC}(duty::Duty{VC}, id::Id{VC}, assigned_form_uid_in_reformulation) where {VC}
    Id{VC}(duty, id.uid, id.origin_form_uid, assigned_form_uid_in_reformulation, id.proc_uid, id.custom_family_id, id._hash)
end

function Id{VC}(duty::Duty{VC}, id::Id{VC}; custom_family_id = id.custom_family_id) where {VC}
    Id{VC}(duty, id.uid, id.origin_form_uid, id.assigned_form_uid_in_reformulation, id.proc_uid, custom_family_id, id._hash)
end

Base.hash(a::Id, h::UInt) = hash(a._hash, h)
Base.isequal(a::Id{VC}, b::Id{VC}) where {VC} = Base.isequal(a._hash, b._hash)
Base.isequal(a::Int, b::Id) = Base.isequal(a, b._hash)
Base.isequal(a::Id, b::Int) = Base.isequal(a._hash, b)
Base.isless(a::Id{VC}, b::Id{VC}) where {VC} = Base.isless(a._hash, b._hash)
Base.zero(I::Type{Id{VC}}) where {VC} = I(Duty{VC}(0), -1, -1, -1, -1, -1, -1)

Base.:(<)(a::Id{VC}, b::Id{VC}) where {VC} = a._hash < b._hash
Base.:(<=)(a::Id{VC}, b::Id{VC}) where {VC} = a._hash <= b._hash
Base.:(==)(a::Id{VC}, b::Id{VC}) where {VC} = a._hash == b._hash
Base.:(>)(a::Id{VC}, b::Id{VC}) where {VC} = a._hash > b._hash
Base.:(>=)(a::Id{VC}, b::Id{VC}) where {VC} = a._hash >= b._hash

getuid(id::Id) = id.uid
getduty(vcid::Id{VC}) where {VC} = vcid.duty
getoriginformuid(id::Id) = id.origin_form_uid
getassignedformuid(id::Id) = id.assigned_form_uid_in_reformulation
getprocuid(id::Id) = id.proc_uid
getsortuid(id::Id) = getuid(id) + 1000000 * getoriginformuid(id)

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, T, "#",
          "u", id.uid,
          "f", id.origin_form_uid,
          "a", id.assigned_form_uid_in_reformulation,
          "p", id.proc_uid ,
          "h", id._hash)
end

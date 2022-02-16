"""
    Id{VC <: AbstractVarConstr} as VarId or ConstrId

Coluna identifier of a `Variable`, a `Constraint`, or a `SingleVarConstraint`.

It is composed by the following uids:
1. `uid`: uid in the formulation where it was generated 
2. `origin_form_uid`: uid of the formulation where it was generated 
3. `assigned_form_uid`: uid of the formulation where it is generated assigned in the reformulation process
4. `proc_uid`: Number of the process where it was generated 
For a origin jump var/constr the origin_form_uid is the jump model while the assigned_form_uid is the spform for a pure spform and the master for a pure master var. For a added var/constr the origin_form_uid is where is was created : for instance a master column 's orginal formulation  is the subproblem for which it was a solution and is assigned formulation is the master program.Number of the process where it was generated 
"""
struct Id{VC <: AbstractVarConstr,F} # F is a flag to differenciate ConstrId & SingleVarConstrId 
    duty::Duty{VC}
    uid::Int32
    origin_form_uid::FormId
    assigned_form_uid::FormId
    proc_uid::Int8
    custom_family_id::Int8
    _hash::Int
end

function _create_hash(uid::Integer, origin_form_uid::Integer, proc_uid::Integer)
    return (
        Int(uid) * Int(MAX_NB_FORMULATIONS) * Int(MAX_NB_PROCESSES)
        + Int(origin_form_uid) * Int(MAX_NB_PROCESSES)
        + Int(proc_uid)
    )
end

function Id{VC,F}(
    duty::Duty{VC}, uid::Integer, origin_form_uid::Integer;
    assigned_form_uid::Integer = origin_form_uid,
    custom_family_id::Integer = -1
) where {VC,F}
    proc_uid = Distributed.myid()
    return Id{VC,F}(
        duty, uid, origin_form_uid, assigned_form_uid, proc_uid, custom_family_id,
        _create_hash(uid, origin_form_uid, proc_uid)
    )
end

function Id{VC,F}(
    orig_id::Id{VC};
    duty::Union{Nothing, Duty{VC}} = nothing,
    origin_form_uid::Union{Nothing, Integer} = nothing,
    assigned_form_uid::Union{Nothing, Integer} = nothing,
    custom_family_id::Union{Nothing, Integer} = nothing,
) where {VC,F}
    duty = duty === nothing ? orig_id.duty : duty
    origin_form_uid = origin_form_uid === nothing ? orig_id.origin_form_uid : origin_form_uid
    assigned_form_uid = assigned_form_uid === nothing ? orig_id.assigned_form_uid : assigned_form_uid
    custom_family_id = custom_family_id === nothing ? orig_id.custom_family_id : custom_family_id
    return Id{VC,F}(
        duty, orig_id.uid, origin_form_uid, assigned_form_uid, orig_id.proc_uid, 
        custom_family_id, _create_hash(orig_id.uid, origin_form_uid, orig_id.proc_uid)
    )
end

Base.hash(a::Id, h::UInt) = hash(a._hash, h)
Base.isequal(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = Base.isequal(a._hash, b._hash)
Base.isequal(a::Int, b::Id) = Base.isequal(a, b._hash)
Base.isequal(a::Id, b::Int) = Base.isequal(a._hash, b)
Base.isless(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = Base.isless(a._hash, b._hash)
Base.zero(I::Type{Id{VC,F}}) where {VC,F} = I(Duty{VC}(0), -1, -1, -1, -1, -1, -1)

Base.:(<)(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = a._hash < b._hash
Base.:(<=)(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = a._hash <= b._hash
Base.:(==)(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = a._hash == b._hash
Base.:(>)(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = a._hash > b._hash
Base.:(>=)(a::Id{VC,F}, b::Id{VC,F}) where {VC,F} = a._hash >= b._hash

getuid(id::Id) = id.uid
getduty(vcid::Id{VC,F}) where {VC,F} = vcid.duty
getoriginformuid(id::Id) = id.origin_form_uid
getassignedformuid(id::Id) = id.assigned_form_uid
getprocuid(id::Id) = id.proc_uid
getsortuid(id::Id) = getuid(id) + 1000000 * getoriginformuid(id)

function Base.show(io::IO, id::Id{T,F}) where {T,F}
    print(io, T, "#(", F ,")",
          "u", id.uid,
          "f", id.origin_form_uid,
          "a", id.assigned_form_uid,
          "p", id.proc_uid,
          "h", id._hash)
end

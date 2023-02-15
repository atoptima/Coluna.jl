"""
Coluna identifier of a `Variable` or a `Constraint`.

The identifier is a subtype of `Integer` so we can use it as index of sparse arrays.
It behaves like an integer (field `uid`) with additional information (other fields).

It is composed by the following ids:
1. `uid`: unique id that is global to the Coluna instance (the integer) 
2. `origin_form_uid`: unique id of the formulation where it was generated 
3. `assigned_form_uid`: unique id of the formulation where it is assigned in the reformulation process

For a JuMP variable/constraint the `origin_form_uid` is the original formulation while the 
`assigned_form_uid` is the subproblem formulation for a pure subproblem variable/constraint 
and the master for a pure master variable/constraint. 

For a variable/constraint generated during optimization, the `origin_form_uid` is 
the id of the formulation where it was created. 
For instance, the origin formulation of a master column is the subproblem for which the 
column is a solution and its assigned formulation is the master.
"""
struct Id{VC <: AbstractVarConstr} <: Integer
    duty::Duty{VC}
    uid::Int
    origin_form_uid::FormId
    assigned_form_uid::FormId
    custom_family_id::Int8
end

function Id{VC}(
    duty::Duty{VC}, uid::Integer, origin_form_uid::Integer;
    assigned_form_uid::Integer = origin_form_uid,
    custom_family_id::Integer = -1
) where {VC}
    return Id{VC}(duty, uid, origin_form_uid, assigned_form_uid, custom_family_id)
end

function Id{VC}(
    orig_id::Id{VC};
    duty::Union{Nothing, Duty{VC}} = nothing,
    origin_form_uid::Union{Nothing, Integer} = nothing,
    assigned_form_uid::Union{Nothing, Integer} = nothing,
    custom_family_id::Union{Nothing, Integer} = nothing,
) where {VC}
    duty = isnothing(duty) ? orig_id.duty : duty
    origin_form_uid = isnothing(origin_form_uid) ? orig_id.origin_form_uid : origin_form_uid
    assigned_form_uid = isnothing(assigned_form_uid) ? orig_id.assigned_form_uid : assigned_form_uid
    custom_family_id = isnothing(custom_family_id) ? orig_id.custom_family_id : custom_family_id
    return Id{VC}(duty, orig_id.uid, origin_form_uid, assigned_form_uid, custom_family_id)
end

# Use of this method should be avoided as much as possible.
# If you face a `VarId` or a `ConstrId` without any additional information, it can mean:
#  - the id does not exist but an integer of type Id was needed (e.g. size of sparse vector);
#  - information have been lost because of chain of converts (e.g. Id with info -> Int -> Id without info)
Id{VC}(uid::Integer) where VC = Id{VC}(Duty{VC}(0), uid, -1, -1, -1)

Base.hash(a::Id, h::UInt) = hash(a.uid, h)
Base.zero(I::Type{Id{VC}}) where {VC} = I(0)
Base.zero(::Id{VC}) where {VC} = Id{VC}(0)
Base.one(I::Type{Id{VC}}) where {VC} = I(1)
Base.typemax(I::Type{Id{VC}}) where {VC} = I(Coluna.MAX_NB_ELEMS)
Base.isequal(a::Id{VC}, b::Id{VC}) where {VC} = isequal(a.uid, b.uid)

Base.promote_rule(::Type{T}, ::Type{<:Id}) where {T<:Integer} = T
Base.promote_rule(::Type{<:Id}, ::Type{T}) where {T<:Integer} = T
Base.promote_rule(::Type{<:Id}, ::Type{<:Id}) = Int

# Promotion mechanism will never call the following rule:
#   Base.promote_rule(::Type{I}, ::Type{I}) where {I<:Id} = Int32
#
# The problem is that an Id is an integer with additional information and we
# cannot generate additional information of a new id from the operation of two
# existing ids.
# As we want that all operations on ids results on operations on the uid,
# we redefine the promotion mechanism for Ids so that operations on Ids return integer:
Base.promote_type(::Type{I}, ::Type{I}) where {I<:Id} = Int32

Base.convert(::Type{Int}, id::I) where {I<:Id} = Int(id.uid)
Base.convert(::Type{Int32}, id::I) where {I<:Id} = id.uid

Base.:(<)(a::Id{VC}, b::Id{VC}) where {VC} = a.uid < b.uid
Base.:(<=)(a::Id{VC}, b::Id{VC}) where {VC} = a.uid <= b.uid
Base.:(==)(a::Id{VC}, b::Id{VC}) where {VC} = a.uid == b.uid
Base.:(>)(a::Id{VC}, b::Id{VC}) where {VC} = a.uid > b.uid
Base.:(>=)(a::Id{VC}, b::Id{VC}) where {VC} = a.uid >= b.uid

ClB.getuid(id::Id) = id.uid # TODO: change name
getduty(vcid::Id{VC}) where {VC} = vcid.duty
getoriginformuid(id::Id) = id.origin_form_uid
getassignedformuid(id::Id) = id.assigned_form_uid
getsortuid(id::Id) = getuid(id)

function Base.show(io::IO, id::Id{T}) where {T}
    print(io, T, "u", id.uid)
end

# Methods that Id needs to implement (otherwise error):
Base.sub_with_overflow(a::I, b::I) where {I<:Id} = Base.sub_with_overflow(a.uid, b.uid)
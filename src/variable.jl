mutable struct Variable <: AbstractVarConstr
    uid::VarId
    name::String
    flag::Flag     # Static, Dynamic, Artifical
    duty::VarDuty
    index::MOI.VariableIndex
    bounds_index::Union{MoiBounds, Nothing}
    type_index::Union{MoiVcType, Nothing}
end

function Variable(m::AbstractModel,  n::String, f::Flag, d::VarDuty)
    uid = getnewuid(m.var_counter)
    return Variable(uid, n, f, d, MOI.VariableIndex(-1), nothing, nothing)
end

function Variable(m::AbstractModel,  n::String)
    return Variable(m, n, Static, OriginalVar)
end

getuid(v::Variable) = v.uid


# struct Variable{DutyType <: AbstractVarDuty} <: AbstractVarConstr
#     uid::Id{Variable} # unique id
#     moi_id::Int  # -1 if not explixitly in a formulation
#     name::Symbol
#     duty::DutyType
#     formulation::Formulation
#     cost::Float64
#     # ```
#     # sense : 'P' = positive
#     # sense : 'N' = negative
#     # sense : 'F' = free
#     # ```
#     sense::VarSense
#     # ```
#     # 'C' = continuous,
#     # 'B' = binary, or
#     # 'I' = integer
#     vc_type::VarSet
#     # ```
#     # 's' -by default- for static VarConstr belonging to the problem -and erased
#     #     when the problem is erased-
#     # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
#     # 'a' for artificial VarConstr.
#     # ```
#     flag::Flag
#     lower_bound::Float64
#     upper_bound::Float64
#     # ```
#     # Active = In the formulation
#     # Inactive = Can enter the formulation, but is not in it
#     # Unsuitable = is not valid for the formulation at the current node.
#     # ```
#     # ```
#     # 'U' or 'D'
#     # ```
#     directive::Char
#     # ```
#     # A higher priority means that var is selected first for branching or diving
#     # ```
#     priority::Float64
#     status::Status

#     # Represents the membership of a VarConstr as map where:
#     # - The key is the index of a constr/var including this as member,
#     # - The value is the corresponding coefficient.
#     # ```
#     constr_membership::Membership
# end

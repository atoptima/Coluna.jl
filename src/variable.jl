mutable struct Variable <: AbstractVarConstr
    uid::VarId
    name::String
    cost::Float64 # rep
    lower_bound::Float64# rep
    upper_bound::Float64 # rep
    vc_type::VarType# rep
    flag::Flag   # rep  # Static, Dynamic, Artifical, Implicit
    duty::VarDuty# rep
    sense::VarSense # rep
    index::MOI.VariableIndex # rep
    bounds_index::Union{MoiBounds, Nothing}# rep
    type_index::Union{MoiVcType, Nothing}# rep
end

function Variable(m::AbstractModel, n::String, c::Float64, lb::Float64, 
        ub::Float64, t::VarType, flag::Flag, d::VarDuty, s::VarSense)
    uid = getnewuid(m.var_counter)
    return Variable(uid, n, c, lb, ub, t, flag, d, s, MOI.VariableIndex(-1), nothing, nothing)
end

function Variable(m::AbstractModel,  n::String)
    return Variable(m, n, 0.0, -Inf, Inf, Continuous, Static, OriginalVar, Free)
end

getuid(v::Variable) = v.uid
getname(v::Variable) = v.name
getcost(v::Variable) = v.cost
getlb(v::Variable) = v.lower_bound
getub(v::Variable) = v.upper_bound
gettype(v::Variable) = v.vc_type
getduty(v::Variable) = v.duty
getsense(v::Variable) = v.sense

setcost!(v::Variable, c::Float64) = v.cost += c
setlowerbound!(v::Variable, lb::Float64) = v.lower_bound = lb
setupperbound!(v::Variable, ub::Float64) = v.upper_bound = ub
setduty!(v::Variable, d::VarDuty) = v.duty = d
settype!(v::Variable, t::VarType) = v.vc_type = t
setsense!(v::Variable, s::VarSense) = v.sense = s

function set!(v::Variable, ::MOI.ZeroOne)
    settype!(v, Binary)
    setsense!(v, Positive)
    (v.lower_bound < 0) && setlowerbound!(v, 0.0)
    (v.upper_bound > 1) && setupperbound!(v, 1.0)
    return
end

function set!(v::Variable, ::MOI.Integer)
    settype!(v, Integ)
    return
end

function set!(v::Variable, s::MOI.GreaterThan)
    lb = float(s.lower)
    (v.lower_bound < lb) && setlowerbound!(v, lb)
    (lb >= 0) && setsense!(v, Positive)
    return
end

function set!(v::Variable, s::MOI.EqualTo)
    val = float(s.value)
    setlowerbound!(v, val)
    setupperbound!(v, val)
    return
end

function set!(v::Variable, s::MOI.LessThan)
    ub = float(s.upper)
    (v.upper_bound > ub) && setupperbound!(v, ub)
    (ub <= 0) && settype!(v, Negative)
    return
end


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

mutable struct Variable <: AbstractVarConstr
    uid        ::VarId 
    name       ::String
    sense      ::VarSense # Positive, Negative, Free
    vc_type    ::VarType   # Continuous, Binary, Integ
    flag       ::Flag     # Static, Dynamic, Artifical
    cost       ::Float64
    lower_bound::Float64
    upper_bound::Float64
end

function Variable(m::AbstractModel, n::String, sense::VarSense, set::VarType, 
        f::Flag, c::Float64, lb::Float64, ub::Float64)
    uid = getnewuid(m.var_counter)
    return Variable(uid, n, sense, set, f, c, lb, ub)
end

function OriginalVariable(m::AbstractModel, n::String)
    return Variable(m, n, Free, Continuous, Static, 0.0, -Inf, Inf)
end

getuid(v::Variable) = v.uid
getuidval(v::Variable) = v.uid.id
setsense!(v::Variable, s::VarSense) = v.sense = s
setset!(v::Variable, s::VarType) = v.vc_type = s
setlowerbound!(v::Variable, lb::Float64) = v.lower_bound = lb
setupperbound!(v::Variable, ub::Float64) = v.upper_bound = ub
setcost!(v::Variable, c::Float64) = v.cost += c

function set!(v::Variable, ::MOI.ZeroOne)
    setset!(v, Binary)
    setsense!(v, Positive)
    (v.lower_bound < 0) && setlowerbound!(v, 0.0)
    (v.upper_bound > 1) && setupperbound!(v, 1.0)
    return
end

function set!(v::Variable, ::MOI.Integer)
    setset!(v, Integ)
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
    (ub <= 0) && setsense!(v, Negative)
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

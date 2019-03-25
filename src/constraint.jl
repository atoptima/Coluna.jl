mutable struct Constraint <: AbstractVarConstr
    uid    ::ConstrId
    name   ::String
    rhs    ::Float64  # rep
    sense  ::ConstrSense # rep # Greater Less Equal
    vc_type::ConstrType   # rep# Core Facultative SubSytem PureMaster SubprobConvexity
    flag   ::Flag    # rep  # Static, Dynamic, Artifical, Implicit
    duty   ::ConstrDuty # rep
    index  ::Union{MOI.ConstraintIndex, Nothing} # rep
end

function Constraint(m::AbstractModel, n::String, rhs::Float64, s::ConstrSense, 
        t::ConstrType, f::Flag, d::ConstrDuty)
    uid = getnewuid(m.constr_counter)
    return Constraint(uid, n, rhs, s, t, f, d, nothing)
end

function Constraint(m::AbstractModel, n::String)
    return Constraint(m, n, 0.0, Greater, Core, Static, OriginalConstr)
end

getuid(c::Constraint) = c.uid
getrhs(c::Constraint) = c.rhs
getname(c::Constraint) = c.name
getsense(c::Constraint) = c.sense
gettype(c::Constraint) = c.vc_type
getflag(c::Constraint) = c.flag
getduty(c::Constraint) = c.duty

setsense!(c::Constraint, s::ConstrSense) = c.sense = s
settype!(c::Constraint, t::ConstrType) = c.vc_type = t
setflag!(c::Constraint, f::Flag) = c.flag = f
setrhs!(c::Constraint, r::Float64) = c.rhs = r

function set!(c::Constraint, s::MOI.GreaterThan)
    rhs = float(s.lower)
    setsense!(c, Greater)
    setrhs!(c, rhs)
    return
end

function set!(c::Constraint, s::MOI.EqualTo)
    rhs = float(s.value)
    setsense!(c, Equal)
    setrhs!(c, rhs)
    return
end

function set!(c::Constraint, s::MOI.LessThan)
    rhs = float(s.upper)
    setsense!(c, Less)
    setrhs!(c, rhs)
    return
end

# struct Constraint{DutyType <: AbstractConstrDuty} <: AbstractVarConstr
#     uid::Id{Constraint}  # unique id
#     moi_id::Int # -1 if not explixitly in a formulation
#     name::Symbol
#     duty::DutyType
#     formulation::Formulation
#     vc_ref::Int
#     rhs::Float64
#     # ```
#     # sense : 'G' = greater or equal to
#     # sense : 'L' = less or equal to
#     # sense : 'E' = equal to
#     # ```
#     sense::ConstrSense
#     # ```
#     # vc_type = 'C' for core -required for the IP formulation-,
#     # vc_type = 'F' for facultative -only helpfull to tighten the LP approximation of the IP formulation-,
#     # vc_type = 'S' for constraints defining a subsystem in column generation for
#     #            extended formulation approach
#     # vc_type = 'M' for constraints defining a pure master constraint
#     # vc_type = 'X' for constraints defining a subproblem convexity constraint in the master
#     # ```
#     vc_type::ConstrType
#     # ```
#     # 's' -by default- for static VarConstr belonging to the problem -and erased
#     #     when the problem is erased-
#     # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
#     # ```
#     flag::Flag
#     # ```
#     # Active = In the formulation
#     # Inactive = Can enter the formulation, but is not in it
#     # Unsuitable = is not valid for the formulation at the current node.
#     # ```
#     status::Status
#     # ```
#     # Represents the membership of a VarConstr as map where:
#     # - The key is the index of a constr/var including this as member,
#     # - The value is the corresponding coefficient.
#     # ```
#     var_membership::Membership
# end

mutable struct Constraint <: AbstractVarConstr
    constr_uid::ConstrId
    form_uid::FormId
    name::String
    rhs::Float64 
    sense::ConstrSense # Greater Less Equal
    kind::ConstrKind  # Core Facultative SubSytem PureMaster SubprobConvexity
    flag::Flag    # Static, Dynamic/Delayed, Implicit
    duty::ConstrDuty 
   # index::MoiConstrIndex
end

function Constraint(m::AbstractModel,
                    form_uid::FormId,
                    name::String,
                    rhs::Float64,
                    sense::ConstrSense, 
                    kind::ConstrKind,
                    flag::Flag,
                    duty::ConstrDuty)
    uid = getnewuid(m.constr_counter)
    return Constraint(uid, form_uid,  name, rhs, sense, kind, flag, duty)
end

function Constraint(m::AbstractModel, name::String)
    return Constraint(m, 0, name, 0.0, Greater, Core, Static, OriginalConstr)
end

getuid(c::Constraint) = c.constr_uid
getform(c::Constraint) = c.form_uid
getrhs(c::Constraint) = c.rhs
getname(c::Constraint) = c.name
getsense(c::Constraint) = c.sense
gettype(c::Constraint) = c.kind
getflag(c::Constraint) = c.flag
getduty(c::Constraint) = c.duty

setform!(c::Constraint, uid::FormId) = c.form_uid = uid
setsense!(c::Constraint, s::ConstrSense) = c.sense = s
settype!(c::Constraint, t::ConstrKind) = c.kind = t
setflag!(c::Constraint, f::Flag) = c.flag = f
setrhs!(c::Constraint, r::Float64) = c.rhs = r
setduty!(c::Constraint, d::ConstrDuty) = c.duty = d

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
#     # kind = 'C' for core -required for the IP formulation-,
#     # kind = 'F' for facultative -only helpfull to tighten the LP approximation of the IP formulation-,
#     # kind = 'S' for constraints defining a subsystem in column generation for
#     #            extended formulation approach
#     # kind = 'M' for constraints defining a pure master constraint
#     # kind = 'X' for constraints defining a subproblem convexity constraint in the master
#     # ```
#     kind::ConstrKind
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

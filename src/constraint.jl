mutable struct Constraint <: AbstractVarConstr
    constr_uid::ConstrId
    form_uid::FormId
    name::String
    rhs::Float64 
    sense::ConstrSense # Greater Less Equal
    kind::ConstrKind  # Core Facultative SubSystem 
    flag::Flag    # Static, Dynamic/Delayed, Implicit
    duty::ConstrDuty 
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

mutable struct Constraint{Duty <: AbstractConstrDuty} <: AbstractVarConstr
    constr_id::Id
    form_uid::FormId
    name::String
    rhs::Float64 
    sense::ConstrSense # Greater Less Equal
    kind::ConstrKind  # Core Facultative SubSystem 
    flag::Flag    # Static, Dynamic/Delayed, Implicit
end

function Constraint(Duty::Type{<: AbstractConstrDuty},
                    m::AbstractModel,
                    form_uid::FormId,
                    name::String,
                    rhs::Float64,
                    sense::ConstrSense, 
                    kind::ConstrKind,
                    flag::Flag)
    uid = getnewuid(m.constr_counter)
    cuid = Id(Constraint, uid)
    return Constraint{Duty}(cuid, form_uid,  name, rhs, sense, kind, flag)
end

function Constraint(m::AbstractModel, name::String)
    return Constraint(OriginalConstr, m, 0, name, 0.0, Greater, Core, Static)
end

mutable struct ConstrInfo <: AbstractVarConstrInfo
    cur_rhs::Float64 
    cur_sense::ConstrSense # Greater Less Equal
    cur_flag::Flag     # Static, Dynamic/Delayed,  Implicit
    cur_status::Status   # Active or not
end

function ConstrInfo(constr::Constraint)
    return ConstrInfo(getrhs(constr), getsense(constr), getflag(constr), Active)
end

function copy(constr::Constraint, form::AbstractFormulation, flag::Flag, Duty::Type{<: AbstractConstrDuty})
    return Constraint{Duty}(Id(getid(constr)), form, getname(constr),
        getrhs(constr), getsense(constr), getkind(constr), flag)
end

indextype(::Type{<: Constraint}) = MoiConstrIndex
infotype(::Type{<: Constraint}) = ConstrInfo

getuid(c::Constraint) = getuid(c.constr_id)
getid(c::Constraint) = c.constr_id
getform(c::Constraint) = c.form_uid
getrhs(c::Constraint) = c.rhs
getname(c::Constraint) = c.name
getsense(c::Constraint) = c.sense
gettype(c::Constraint) = c.kind
getkind(c::Constraint) = c.kind
getflag(c::Constraint) = c.flag
getduty(c::Constraint{T}) where {T <: AbstractConstrDuty} = T

setform!(c::Constraint, uid::FormId) = c.form_uid = uid
setname!(c::Constraint, name::String) = c.name = name
setsense!(c::Constraint, s::ConstrSense) = c.sense = s
settype!(c::Constraint, t::ConstrKind) = c.kind = t
setflag!(c::Constraint, f::Flag) = c.flag = f
setrhs!(c::Constraint, r::Float64) = c.rhs = r
#setduty!(c::Constraint, d::ConstrDuty) = c.duty = d

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

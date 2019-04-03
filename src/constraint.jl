mutable struct Constraint <: AbstractVarConstr
    form_uid::FormId
    name::String
    rhs::Float64 
    sense::ConstrSense # Greater Less Equal
    kind::ConstrKind  # Core Facultative SubSystem 
end

function Constraint(name::String)
    return Constraint(0, name, 0.0, Greater, Core, Static)
end

mutable struct ConstrInfo{Duty <: AbstractConstrDuty} <: AbstractVarConstrInfo
    cur_rhs::Float64 
    cur_sense::ConstrSense # Greater Less Equal
    cur_status::Status   # Active or not
    index::MoiConstrIndex
end

function ConstrInfo(Duty::Type{<: AbstractConstrDuty},
                    constr::Constraint)x
    return ConstrInfo{Duty}(getrhs(constr), getsense(constr),  Active, nothing)
end

infotype(::Type{<: ConstrInfo}) = Constraint

infotype(::Type{<: Constraint}) = ConstrInfo

getduty(ci::ConstrInfo{T}) where {T <: AbstractVarDuty} = T

#==function copy(vc::T, flag::Flag, Duty::Type{<: AbstractDuty},
              form_uid::Int) where {T <: AbstractVarConstr}
    return T{Duty}(Id(getid(vc)), form_uid, getname(vc),
                   getrhs(constr), getsense(constr), getkind(constr), flag)
end


function copy(constr::Constraint, flag::Flag, Duty::Type{<: AbstractConstrDuty},
              form_uid::Int)
    return Constraint{Duty}(Id(getid(constr)), form_uid, getname(constr),
        getrhs(constr), getsense(constr), getkind(constr), flag)
end
==#

indextype(::Type{Constraint}) = MoiConstrIndex
idtype(::Type{Constraint}) = Id{Constraint, ConstrInfo}

getform(c::Constraint) = c.form_uid
getrhs(c::Constraint) = c.rhs
getname(c::Constraint) = c.name
getsense(c::Constraint) = c.sense
gettype(c::Constraint) = c.kind
getkind(c::Constraint) = c.kind
getflag(c::Constraint) = c.flag

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

mutable struct Constraint <: AbstractVarConstr
    form_uid::FormId
    name::String
    rhs::Float64 
    sense::ConstrSense # Greater Less Equal
    kind::ConstrKind  # Core Facultative SubSystem 
end

function Constraint(name::String)
    return Constraint(0, name, 0.0, Greater, Core)
end

getform(c::Constraint) = c.form_uid
getrhs(c::Constraint) = c.rhs
getname(c::Constraint) = c.name
getsense(c::Constraint) = c.sense
getkind(c::Constraint) = c.kind

setform!(c::Constraint, uid::FormId) = c.form_uid = uid
setname!(c::Constraint, name::String) = c.name = name
setrhs!(c::Constraint, r::Float64) = c.rhs = r
setsense!(c::Constraint, s::ConstrSense) = c.sense = s
setkind!(c::Constraint, t::ConstrKind) = c.kind = t

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

mutable struct ConstrInfo <: AbstractVarConstrInfo
    cur_rhs::Float64 
    cur_sense::ConstrSense # Greater Less Equal
    cur_status::Status   # Active or not
    index::MoiConstrIndex # -> moi_index
    duty::DataType
end

function ConstrInfo(Duty::Type{<: AbstractConstrDuty},
                    constr::Constraint)
    return ConstrInfo(getrhs(constr), getsense(constr), Active, nothing, Duty)
end

getrhs(c::ConstrInfo) = c.cur_rhs
getsense(c::ConstrInfo) = c.cur_sense
getstatus(c::ConstrInfo) = c.cur_status
getmoiindex(c::ConstrInfo) = c.index
getduty(c::ConstrInfo) = c.duty

setrhs!(c::ConstrInfo, rhs::Float64) = c.cur_rhs = rhs
setsense!(c::ConstrInfo, s::ConstrSense) = c.cur_sense = s
setstatus!(c::ConstrInfo, s::Status) = c.cur_status = s

# TODO :

vctype(::Type{<: ConstrInfo}) = Constraint
infotype(::Type{<: Constraint}) = ConstrInfo

indextype(::Type{Constraint}) = MoiConstrIndex
idtype(::Type{Constraint}) = Id{ConstrInfo}


#setduty!(c::Constraint, d::ConstrDuty) = c.duty = d
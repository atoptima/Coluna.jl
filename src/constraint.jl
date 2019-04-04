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

mutable struct ConstrState <: AbstractVarConstrState
    cur_rhs::Float64 
    cur_sense::ConstrSense # Greater Less Equal
    cur_status::Status   # Active or not
    index::MoiConstrIndex # -> moi_index
    duty::DataType
end

function ConstrState(Duty::Type{<: AbstractConstrDuty},
                    constr::Constraint)
    return ConstrState(getrhs(constr), getsense(constr), Active, nothing, Duty)
end

getrhs(c::ConstrState) = c.cur_rhs
getsense(c::ConstrState) = c.cur_sense
getstatus(c::ConstrState) = c.cur_status
getmoi_index(c::ConstrState) = c.index
getduty(c::ConstrState) = c.duty

setrhs!(c::ConstrState, rhs::Float64) = c.cur_rhs = rhs
setsense!(c::ConstrState, s::ConstrSense) = c.cur_sense = s
setstatus!(c::ConstrState, s::Status) = c.cur_status = s

# TODO :

vctype(::Type{<: ConstrState}) = Constraint
infotype(::Type{<: Constraint}) = ConstrState

indextype(::Type{Constraint}) = MoiConstrIndex
idtype(::Type{Constraint}) = Id{ConstrState}


#setduty!(c::Constraint, d::ConstrDuty) = c.duty = d

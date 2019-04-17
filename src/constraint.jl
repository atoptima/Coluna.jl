mutable struct ConstrData <: AbstractVcData
    rhs::Float64 
    kind::ConstrKind
    sense::ConstrSense
    is_active::Bool
end
function ConstrData(; rhs::Float64  = -Inf,
                    kind::ConstrKind = Core,
                    sense::ConstrSense = Greater,
                    is_active::Bool = true)
    return ConstrData(rhs, kind, sense, is_active)
end

getrhs(c::ConstrData) = c.rhs
is_active(vc::AbstractVcData) = vc.is_active
getkind(vc::AbstractVcData) = vc.kind
getsense(vc::AbstractVcData) = vc.sense

setrhs!(s::ConstrData, rhs::Float64) = s.rhs = rhs
set_is_active!(vc::AbstractVcData, is_active::Bool) = vc.is_active = is_active
setkind!(vc::AbstractVcData, kind) = vc.kind = kind
setsense!(vc::AbstractVcData, sense) = vc.sense = sense

mutable struct MoiConstrRecord
    index::MoiConstrIndex
end
MoiConstrRecord(;index = MoiConstrIndex()) = MoiConstrRecord(MoiConstrIndex())

get_index(record::MoiConstrRecord) = record.index
set_index(record::MoiConstrRecord, index::MoiConstrIndex) = record.index = index

struct Constraint <: AbstractVarConstr
    id::Id{Constraint}
    name::String
    duty::Type{<: AbstractConstrDuty}
    initial_data::ConstrData
    cur_data::ConstrData
    moi_record::MoiConstrRecord
end
const ConstrId = Id{Constraint}

function Constraint(id::ConstrId,
                    name::String,
                    duty::Type{<:AbstractConstrDuty};
                    constr_data = ConstrData(),
                    moi_index::MoiConstrIndex = MoiConstrIndex())
    return Constraint(
        id, name, duty, constr_data, constr_data,
        MoiConstrRecord(index = moi_index)
    )
end

getid(vc::AbstractVarConstr) = vc.id
getuid(vc::AbstractVarConstr) = getuid(vc.id)
getname(vc::AbstractVarConstr) = vc.name
getduty(vc::AbstractVarConstr) = vc.duty
setduty(vc::AbstractVarConstr, d::Type{<:AbstractDuty}) = vc.duty = d

get_initial_data(vc::AbstractVarConstr) = vc.initial_data
get_cur_data(vc::AbstractVarConstr) = vc.cur_data
get_moi_record(vc::AbstractVarConstr) = vc.moi_record

function reset!(c::Constraint)
    initial = get_initial_data(c)
    cur = get_cur_data(c)
    cur.rhs = initial.rhs
    cur.kind = initial.kind
    cur.sense = initial.sense
    cur.is_active = initial.is_active
    return
end

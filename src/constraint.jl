mutable struct ConstrData <: AbstractVcData
    rhs::Float64 
    kind::ConstrKind
    sense::ConstrSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

function ConstrData(; rhs::Float64  = -Inf,
                    kind::ConstrKind = Core,
                    sense::ConstrSense = Greater,
                    inc_val::Float64 = -1.0,
                    is_active::Bool = true,
                    is_explicit::Bool = true)
    return ConstrData(rhs, kind, sense, inc_val, is_active, is_explicit)
end

get_rhs(c::ConstrData) = c.rhs
is_active(vc::AbstractVcData) = vc.is_active
is_explicit(vc::AbstractVcData) = vc.is_explicit
get_kind(vc::AbstractVcData) = vc.kind
get_sense(vc::AbstractVcData) = vc.sense
get_inc_val(vc::AbstractVcData) = vc.inc_val

is_active(vc::AbstractVarConstr) = vc.cur_data.is_active
is_explicit(vc::AbstractVarConstr) = vc.cur_data.is_explicit

set_rhs!(s::ConstrData, rhs::Float64) = s.rhs = rhs
set_inc_val!(vc::AbstractVcData, val::Float64) =  vc.inc_val = val
set_is_active!(vc::AbstractVcData, is_active::Bool) = vc.is_active = is_active
set_is_explicit!(vc::AbstractVcData, is_explicit::Bool) = vc.is_explicit = is_explicit
set_kind!(vc::AbstractVcData, kind) = vc.kind = kind
set_sense!(vc::AbstractVcData, sense) = vc.sense = sense

mutable struct MoiConstrRecord
    index::MoiConstrIndex
end

MoiConstrRecord(;index = MoiConstrIndex()) = MoiConstrRecord(MoiConstrIndex())

get_index(record::MoiConstrRecord) = record.index
set_index!(record::MoiConstrRecord, index::MoiConstrIndex) = record.index = index

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
        id, name, duty, constr_data, deepcopy(constr_data),
        MoiConstrRecord(index = moi_index)
    )
end

get_id(vc::AbstractVarConstr) = vc.id
get_uid(vc::AbstractVarConstr) = get_uid(vc.id)
get_name(vc::AbstractVarConstr) = vc.name
get_duty(vc::AbstractVarConstr) = vc.duty
set_duty!(vc::AbstractVarConstr, d::Type{<:AbstractDuty}) = vc.duty = d

get_initial_data(vc::AbstractVarConstr) = vc.initial_data
get_cur_data(vc::AbstractVarConstr) = vc.cur_data
get_moi_record(vc::AbstractVarConstr) = vc.moi_record

function reset!(c::Constraint)
    initial = get_initial_data(c)
    cur = get_cur_data(c)
    cur.rhs = initial.rhs
    cur.inc_val = initial.inc_val
    cur.kind = initial.kind
    cur.sense = initial.sense
    cur.is_active = initial.is_active
    return
end

get_rhs(c::Constraint) = get_rhs(c.cur_data)
is_active(c::Constraint) = is_active(c.cur_data)
is_explicit(c::Constraint) = is_explicit(c.cur_data)
get_kind(c::Constraint) = get_kind(c.cur_data)
get_sense(c::Constraint) = get_sense(c.cur_data)
get_inc_val(c::Constraint) = get_inc_val(c.cur_data)
set_rhs!(c::Constraint, rhs::Float64) = set_rhs!(c.initial_data, rhs)
set_inc_val!(c::Constraint, val::Float64) = set_inc_val!(c.initial_data, val)
set_is_active!(c::Constraint, is_active::Bool) =  set_is_active!(c.initial_data, is_active)
set_is_explicit!(c::Constraint, is_explicit::Bool) =  set_is_explicit!(c.initial_data, is_explicit)
set_kind!(c::Constraint, kind) =  set_kind!(c.initial_data, kind)
set_sense!(c::Constraint, sense) = set_sense!(c.initial_data, sense)

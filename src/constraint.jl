"""
    ConstrData

Information that defines a state of a constraint. These are the fields of a constraint that might change during the solution procedure.
"""
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

# Attention: Some getters and setters of ConstrData are defined over
#            AbstractVcData in file varconstr.jl

getrhs(c::ConstrData) = c.rhs
set_rhs!(s::ConstrData, rhs::Float64) = s.rhs = rhs

"""
    MoiConstrRecord

Structure to hold the pointers to the MOI representation of a Coluna Constraint.
"""
mutable struct MoiConstrRecord
    index::MoiConstrIndex
end

MoiConstrRecord(;index = MoiConstrIndex()) = MoiConstrRecord(index)

getindex(record::MoiConstrRecord) = record.index
setindex!(record::MoiConstrRecord, index::MoiConstrIndex) = record.index = index

"""
    Constraint

Representation of a constraint in Coluna.
"""
struct Constraint <: AbstractVarConstr
    id::Id{Constraint}
    name::String
    duty::Type{<: AbstractConstrDuty}
    recorded_data::ConstrData
    cur_data::ConstrData
    moirecord::MoiConstrRecord
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

# Note: Several getters and setters for Constraint are defined
#       over AbstractVarConstr in file varconstr.jl

# Initial
getcurrhs(vc::Constraint) = vc.cur_data.rhs
setcurrhs!(vc::Constraint, rhs) = setcurrhs!(vc, float(rhs))
setcurrhs!(vc::Constraint, rhs::Float64) = vc.cur_data.rhs = rhs
# Current
getinitrhs(vc::Constraint) = vc.recorded_data.rhs
#set_init_rhs!(vc::AbstractVarConstr, rhs::Float64) = vc.recorded_data.rhs = rhs

function reset!(c::Constraint)
    initial = getrecordeddata(c)
    cur = getcurdata(c)
    cur.rhs = initial.rhs
    cur.inc_val = initial.inc_val
    cur.kind = initial.kind
    cur.sense = initial.sense
    cur.is_active = initial.is_active
    return
end

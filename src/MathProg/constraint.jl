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

getrhs(c::ConstrData) = c.rhs
setrhs!(s::ConstrData, rhs::Float64) = s.rhs = rhs

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
    duty::AbstractConstrDuty
    perene_data::ConstrData
    cur_data::ConstrData
    moirecord::MoiConstrRecord
end
const ConstrId = Id{Constraint}

function Constraint(id::ConstrId,
                    name::String,
                    duty::AbstractConstrDuty;
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
getperenerhs(vc::Constraint) = vc.perene_data.rhs
#set_init_rhs!(vc::AbstractVarConstr, rhs::Float64) = vc.peren_data.rhs = rhs

function reset!(c::Constraint)
    c.cur_data.rhs = c.perene_data.rhs
    c.cur_data.inc_val = c.perene_data.inc_val
    c.cur_data.kind = c.perene_data.kind
    c.cur_data.sense = c.perene_data.sense
    c.cur_data.is_active = c.perene_data.is_active
    return
end

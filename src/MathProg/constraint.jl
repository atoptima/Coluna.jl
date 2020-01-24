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

ConstrData(cd::ConstrData) = ConstrData(
cd.rhs,
cd.kind,
cd.sense,
cd.inc_val,
cd.is_active,
cd.is_explicit
)

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
    duty::Duty{Constraint}
    perene_data::ConstrData
    moirecord::MoiConstrRecord
end
const ConstrId = Id{Constraint}

function Constraint(id::ConstrId,
                    name::String,
                    duty::Duty{Constraint};
                    constr_data = ConstrData(),
                    moi_index::MoiConstrIndex = MoiConstrIndex())
    return Constraint(
        id, name, duty, constr_data, 
        MoiConstrRecord(index = moi_index)
    )
end


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

get_rhs(c::ConstrData) = c.rhs
set_rhs!(s::ConstrData, rhs::Float64) = s.rhs = rhs

mutable struct MoiConstrRecord
    index::MoiConstrIndex
end

MoiConstrRecord(;index = MoiConstrIndex()) = MoiConstrRecord(index)

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

# Attention: All getters and setters for Constraint are defined
#            over AbstractVarConstr in file varconstr.jl

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

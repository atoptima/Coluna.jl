"""
Information that defines a state of a constraint. 
These data might change during the optimisation procedure.
"""
mutable struct ConstrData <: AbstractVcData
    rhs::Float64
    kind::ConstrKind
    sense::ConstrSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

function ConstrData(; 
    rhs::Float64  = -Inf,
    kind::ConstrKind = Essential,
    sense::ConstrSense = Greater,
    inc_val::Float64 = -1.0,
    is_active::Bool = true,
    is_explicit::Bool = true
)
    return ConstrData(rhs, kind, sense, inc_val, is_active, is_explicit)
end

ConstrData(cd::ConstrData) = ConstrData(
    cd.rhs, cd.kind, cd.sense, cd.inc_val, cd.is_active, cd.is_explicit
)

"Structure to hold the pointers to the MOI representation of a Coluna Constraint."
mutable struct MoiConstrRecord
    index::MoiConstrIndex
end

MoiConstrRecord(;index = MoiConstrIndex()) = MoiConstrRecord(index)

getmoiindex(record::MoiConstrRecord)::MoiConstrIndex = record.index
setmoiindex!(record::MoiConstrRecord, index::MoiConstrIndex) = record.index = index

"""
Representation of a constraint in Coluna.
Coefficients of variables involved in the constraints are stored in the coefficient matrix.
"""
mutable struct Constraint <: AbstractVarConstr
    id::Id{Constraint}
    name::String
    perendata::ConstrData
    curdata::ConstrData
    moirecord::MoiConstrRecord
    art_var_ids::Vector{VarId}
    custom_data::Union{Nothing, BD.AbstractCustomData}
end

const ConstrId = Id{Constraint}

# Internal use only, see `MathProg.setconstr!` to create a constraint.
function Constraint(
    id::ConstrId, name::String;
    constr_data = ConstrData(), moi_index::MoiConstrIndex = MoiConstrIndex(),
    custom_data::Union{Nothing, BD.AbstractCustomData} = nothing
)
    return Constraint(
        id, name, constr_data, ConstrData(constr_data), MoiConstrRecord(index = moi_index), 
        VarId[], custom_data
    )
end

"""
Constraints generator (cut callback).
"""
mutable struct RobustConstraintsGenerator
    nb_generated::Int
    kind::ConstrKind
    separation_alg::Function
end
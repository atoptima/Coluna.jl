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

getindex(record::MoiConstrRecord) = record.index
setindex!(record::MoiConstrRecord, index::MoiConstrIndex) = record.index = index

"""
There are 2 types of constraints in Coluna (i.e. Constraint & SingleVarConstraint).
Both of them inherits from AbstractConstraint because their setters and getters
are quite similar.
"""
abstract type AbstractConstraint <: AbstractVarConstr end

"""
Representation of a constraint in Coluna.
Coefficients of variables involved in the constraints are stored in the coefficient matrix.
If the constraint involves only one variable, you should use a `SingleVarConstraint`.
"""
mutable struct Constraint <: AbstractConstraint
    id::Id{Constraint,:usual}
    name::String
    perendata::ConstrData
    curdata::ConstrData
    moirecord::MoiConstrRecord
    art_var_ids::Vector{VarId}
    custom_data::Union{Nothing, BD.AbstractCustomData}
end

const ConstrId = Id{Constraint,:usual}

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
Representation of a single variable constraint in Coluna : lb <= 1*var <= ub.
For performance reasons, Coluna does not store these constraints in the coefficient matrix
and they are never pushed in the subsolver of a formulation.
Coluna takes into account those constraints only during the bound propagation operation
which updates the current upper and lower bounds of the variable.
"""
mutable struct SingleVarConstraint <: AbstractConstraint
    id::Id{Constraint,:single}
    name::String
    varid::VarId
    perendata::ConstrData
    curdata::ConstrData
end

const SingleVarConstrId = Id{Constraint,:single}

# Internal use only, see `MathProg.setsinglevarconstr!` to create a single var constraint.
function SingleVarConstraint(
    id::SingleVarConstrId, varid::VarId, name::String; constr_data = ConstrData()
)
    return SingleVarConstraint(id, name, varid, constr_data, ConstrData(constr_data))
end

"""
Constraints generator (cut callback).
"""
mutable struct RobustConstraintsGenerator
    nb_generated::Int
    kind::ConstrKind
    separation_alg::Function
end
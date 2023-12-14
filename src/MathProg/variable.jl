abstract type AbstractVarData <: AbstractVcData end

mutable struct VarData <: AbstractVcData
    cost::Float64
    lb::Float64
    ub::Float64
    kind::VarKind
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
    is_in_partial_sol::Bool
end

"""
    VarData

Information that defines a state of a variable.
"""
function VarData(
    ;cost::Float64 = 0.0, lb::Float64 = 0.0, ub::Float64 = Inf, kind::VarKind = Continuous,
    inc_val::Float64 = -1.0, is_active::Bool = true, is_explicit::Bool = true
)
    vc = VarData(cost, lb, ub, kind, inc_val, is_active, is_explicit, false)
    return vc
end

VarData(vd::VarData) = VarData(
    vd.cost, vd.lb, vd.ub, vd.kind, vd.inc_val, vd.is_active, vd.is_explicit, vd.is_in_partial_sol
)

"""
    MoiVarRecord

Structure to hold the pointers to the MOI representation of a Coluna Variable.
"""
mutable struct MoiVarRecord
    index::MoiVarIndex
    lower_bound::Union{Nothing, MoiVarLowerBound}
    upper_bound::Union{Nothing, MoiVarUpperBound}
    kind::MoiVarKind
end

function MoiVarRecord(;index::MoiVarIndex = MoiVarIndex())
    return MoiVarRecord(index, MoiVarLowerBound(), MoiVarUpperBound(), MoiVarKind())
end

getmoiindex(record::MoiVarRecord)::MoiVarIndex = record.index
getlowerbound(record::MoiVarRecord) = record.lower_bound
getupperbound(record::MoiVarRecord) = record.upper_bound
getkind(record::MoiVarRecord) = record.kind

setmoiindex!(record::MoiVarRecord, index::MoiVarIndex) = record.index = index
setlowerbound!(record::MoiVarRecord, bound::MoiVarLowerBound) = record.lower_bound = bound
setupperbound!(record::MoiVarRecord, bound::MoiVarUpperBound) = record.upper_bound = bound
setkind!(record::MoiVarRecord, kind::MoiVarKind) = record.kind = kind

"""
    Variable

Representation of a variable in Coluna.
"""
mutable struct Variable <: AbstractVarConstr
    id::Id{Variable}
    name::String
    perendata::VarData
    curdata::VarData
    branching_priority::Float64
    moirecord::MoiVarRecord
    custom_data::Union{Nothing, BD.AbstractCustomVarData}
end

const VarId = Id{Variable}

getid(var::Variable) = var.id

function Variable(
    id::VarId, name::String; var_data = VarData(), moi_index::MoiVarIndex = MoiVarIndex(),
    custom_data::Union{Nothing, BD.AbstractCustomVarData} = nothing, branching_priority = 1.0
)
    return Variable(
        id, name, var_data, VarData(var_data), branching_priority,
        MoiVarRecord(index = moi_index), custom_data
    )
end

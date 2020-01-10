abstract type AbstractVarData <: AbstractVcData end

struct VarData <: AbstractVcData
    cost::Float64
    lb::Float64
    ub::Float64
    kind::VarKind
    sense::VarSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

function _set_bounds_acc_kind!(vdata::VarData, kind::VarKind)
    if kind == Binary
        if vdata.lb < 0
            vdata.lb = 0
        end
        if vdata.ub > 1
            vdata.ub = 0
        end
    elseif kind == Integer
        vdata.lb = ceil(vdata.lb)
        vdata.ub = floor(vdata.ub)
    end
    return
end

"""
    VarData

Information that defines a state of a variable.
"""
function VarData(
    ;cost::Float64 = 0.0,
    lb::Float64 = 0.0,
    ub::Float64 = Inf,
    kind::VarKind = Continuous,
    sense::VarSense = Positive,
    inc_val::Float64 = -1.0,
    is_active::Bool = true,
    is_explicit::Bool = true
)
    vc = VarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
    _set_bounds_acc_kind!(vc, kind)
    return vc
end

mutable struct VarCurData <: AbstractVcData
    kind::VarKind
    sense::VarSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

"""
    VarCurData

Subset of the information stored in VarData. Current state of the variable.
"""
function VarCurData(
    ;kind::VarKind = Continuous,
    sense::VarSense = Positive,
    inc_val::Float64 = -1.0,
    is_active::Bool = true,
    is_explicit::Bool = true
)
    vc = VarCurData(kind, sense, inc_val, is_active, is_explicit)
    return vc
end

function VarCurData(vardata::VarData)
    return VarCurData(
        vardata.kind, vardata.sense, vardata.inc_val, vardata.is_active, 
        vardata.is_explicit
    )
end

"""
    MoiVarRecord

Structure to hold the pointers to the MOI representation of a Coluna Variable.
"""
mutable struct MoiVarRecord
    index::MoiVarIndex
    bounds::MoiVarBound
    kind::MoiVarKind
end

MoiVarRecord(;index::MoiVarIndex = MoiVarIndex()) = MoiVarRecord(
    index, MoiVarBound(), MoiVarKind()
)
getindex(record::MoiVarRecord) = record.index
getbounds(record::MoiVarRecord) = record.bounds
getkind(record::MoiVarRecord) = record.kind

setindex!(record::MoiVarRecord, index::MoiVarIndex) = record.index = index
setbounds!(record::MoiVarRecord, bounds::MoiVarBound) = record.bounds = bounds
setkind!(record::MoiVarRecord, kind::MoiVarKind) = record.kind = kind

"""
    Variable

Representation of a variable in Coluna.
"""
struct Variable <: AbstractVarConstr
    id::Id{Variable}
    name::String
    duty::AbstractVarDuty
    perene_data::VarData
    cur_data::VarCurData
    moirecord::MoiVarRecord
    # form_where_explicit::Int
end
const VarId = Id{Variable}

getid(var::Variable) = var.id

function Variable(id::VarId,
                  name::String,
                  duty::AbstractVarDuty;
                  var_data = VarData(),
                  moi_index::MoiVarIndex = MoiVarIndex())
    return Variable(
        id, name, duty, var_data, VarCurData(var_data), 
        MoiVarRecord(index = moi_index)
    )
end
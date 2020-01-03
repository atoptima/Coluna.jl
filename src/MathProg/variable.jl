"""
    VarData

Information that defines a state of a variable. These are the fields of a variable that might change during the solution procedure.
"""
abstract type AbstractVarData <: AbstractVcData end

struct PerenVarData <: AbstractVcData
    cost::Float64
    lb::Float64
    ub::Float64
    kind::VarKind
    sense::VarSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

function _setkind!(v::PerenVarData, kind::VarKind)
    if kind == Binary
        v.kind = Binary
        (v.lb < 0) && setlb!(v, 0.0)
        (v.ub > 1) && setub!(v, 1.0)
    end
    return
end

function PerenVarData(
    ;cost::Float64 = 0.0,
    lb::Float64 = 0.0,
    ub::Float64 = Inf,
    kind::VarKind = Continuous,
    sense::VarSense = Positive,
    inc_val::Float64 = -1.0,
    is_active::Bool = true,
    is_explicit::Bool = true
)
    vc = PerenVarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
    _setkind!(vc, kind)
    return vc
end

mutable struct VarData <: AbstractVcData
    kind::VarKind
    sense::VarSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

function VarData(
    ;kind::VarKind = Continuous,
    sense::VarSense = Positive,
    inc_val::Float64 = -1.0,
    is_active::Bool = true,
    is_explicit::Bool = true
)
    vc = VarData(kind, sense, inc_val, is_active, is_explicit)
    return vc
end

getcost(v::VarData) = v.cost
getlb(v::VarData) = v.lb
getub(v::VarData) = v.ub

setcost!(v::VarData, cost::Float64) = v.cost = cost
setlb!(v::VarData, lb::Float64) = v.lb = lb
setub!(v::VarData, ub::Float64) = v.ub = ub


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
    cur_data::VarData
    moirecord::MoiVarRecord
    # form_where_explicit::Int
end
const VarId = Id{Variable}

function Variable(id::VarId,
                  name::String,
                  duty::AbstractVarDuty;
                  var_data = VarData(),
                  moi_index::MoiVarIndex = MoiVarIndex())
    return Variable(
        id, name, duty, var_data, deepcopy(var_data), 
        MoiVarRecord(index = moi_index)
    )
end

function setcurkind(var::Variable, kind::VarKind)
    var.cur_data.kind = kind
    if kind == Binary
        var.cur_data.lb = 0.0
        var.cur_data.ub = 1.0
    end
    return
end

# Attention: All getters and setters for Variable are defined
#            over AbstractVarConstr in file varconstr.jl

function reset!(v::Variable)
    v.cur_data.cost = v.perene_data.cost
    v.cur_data.lb = v.perene_data.lb
    v.cur_data.ub = v.perene_data.ub
    v.cur_data.inc_val = v.perene_data.inc_val
    v.cur_data.kind = v.perene_data.kind
    v.cur_data.sense = v.perene_data.sense
    v.cur_data.is_active = v.perene_data.is_active
    return
end

# Helpers for getters  and stter that acces fields in a level under Variable

# -> Initial
getperenecost(vc::AbstractVarConstr) = vc.perene_data.cost
getperenelb(vc::AbstractVarConstr) = vc.perene_data.lb
getpereneub(vc::AbstractVarConstr) = vc.perene_data.ub
# -> Current
getcurcost(vc::AbstractVarConstr) = vc.cur_data.cost
getcurlb(vc::AbstractVarConstr) = vc.cur_data.lb
getcurub(vc::AbstractVarConstr) = vc.cur_data.ub
setcurcost!(vc::AbstractVarConstr, cost::Float64) = vc.cur_data.cost = cost
setcurlb!(vc::AbstractVarConstr, lb::Float64) = vc.cur_data.lb = lb
setcurub!(vc::AbstractVarConstr, ub::Float64) = vc.cur_data.ub = ub

"""
    VarData

Information that defines a state of a variable. These are the fields of a variable that might change during the solution procedure.
"""
mutable struct VarData <: AbstractVcData
    cost::Float64
    lb::Float64
    ub::Float64
    kind::VarKind
    sense::VarSense
    inc_val::Float64
    is_active::Bool
    is_explicit::Bool
end

function VarData(; cost::Float64 = 0.0,
                 lb::Float64 = 0.0,
                 ub::Float64 = Inf,
                 kind::VarKind = Continuous,
                 sense::VarSense = Positive,
                 inc_val::Float64 = -1.0,
                 is_active::Bool = true,
                 is_explicit::Bool = true)
    return VarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
end

# Attention: Some getters and setters of VarData are defined over AbstractVcData
#            in file varconstr.jl

getcost(v::VarData) = v.cost
getlb(v::VarData) = v.lb
getub(v::VarData) = v.ub

setcost!(v::VarData, cost::Float64) = v.cost = cost
setlb!(v::VarData, lb::Float64) = v.lb = lb
setub!(v::VarData, ub::Float64) = v.ub = ub

function setkind!(v::VarData, kind::VarKind)
    if kind == Binary
        v.kind = Binary
        (v.lb < 0) && setlb!(v, 0.0)
        (v.ub > 1) && setub!(v, 1.0)
    elseif kind == Integ
        v.kind = Integ
    end
    return
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
    duty::Type{<: AbstractVarDuty}
    perene_data::VarData
    cur_data::VarData
    moirecord::MoiVarRecord
    # form_where_explicit::Int
end
const VarId = Id{Variable}

function Variable(id::VarId,
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  var_data = VarData(),
                  moi_index::MoiVarIndex = MoiVarIndex())
    return Variable(
        id, name, duty, var_data, deepcopy(var_data),

        MoiVarRecord(index = moi_index)
    )
end

# Attention: All getters and setters for Variable are defined
#            over AbstractVarConstr in file varconstr.jl

function reset!(v::Variable)
    initial = getrecordeddata(v)
    cur = getcurdata(v)
    cur.cost = initial.cost
    cur.lb = initial.lb
    cur.ub = initial.ub
    cur.inc_val = initial.inc_val
    cur.kind = initial.kind
    cur.sense = initial.sense
    cur.is_active = initial.is_active
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

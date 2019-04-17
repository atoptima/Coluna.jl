mutable struct VarData <: AbstractVcData
    cost::Float64
    lower_bound::Float64
    upper_bound::Float64
    kind::VarKind
    sense::VarSense
    is_active::Bool
end

function VarData(; cost::Float64 = 0.0,
                 lb::Float64 = 0.0,
                 ub::Float64 = Inf,
                 kind::VarKind = Continuous,
                 sense::VarSense = Positive,
                 is_active::Bool = true)
    return VarData(cost, lb, ub, kind, sense, is_active)
end

# Attention: Some getters and setters are defined over AbstractVcData
#            in file constraint.jl
getcost(v::VarData) = v.cost
getlb(v::VarData) = v.lower_bound
getub(v::VarData) = v.upper_bound

setcost!(v::VarData, cost::Float64) = v.cost = cost
setlb!(v::VarData, lb::Float64) = v.lower_bound = lb
setub!(v::VarData, ub::Float64) = v.upper_bound = ub

function set_bound(v::VarData, sense::ConstrSense, bound::Float64)
    if sense == Less || sense == Equal
        set_ub(v, bound)
    elseif sense == Greater || sense == Equal
        set_lb(v, bound)
    end
    return
end

function set_kind(v::VarData, kind::VarKind)
    if kind == Binary
        v.kind = Binary
        (v.lower_bound < 0) && setlb!(v, 0.0)
        (v.upper_bound > 1) && setub!(v, 1.0)
    elseif kind == Integ
        v.kind = Integ
    end
    return
end

mutable struct MoiVarRecord
    index::MoiVarIndex
    bounds::MoiVarBound
    kind::MoiVarKind
end
    
MoiVarRecord(;index::MoiVarIndex = MoiVarIndex()) = MoiVarRecord(
    index, MoiVarBound(), MoiVarKind()
)
get_index(record::MoiVarRecord) = record.index
get_bounds(record::MoiVarRecord) = record.bounds
get_kind(record::MoiVarRecord) = record.kind

set_index(record::MoiVarRecord, index::MoiVarIndex) = record.index = index
set_bounds(record::MoiVarRecord, bnds::MoiVarBound) = record.bounds = bnds
set_kind(record::MoiVarRecord, kind::MoiVarKind) = record.kind = kind

struct Variable <: AbstractVarConstr
    id::Id{Variable}
    name::String
    duty::Type{<: AbstractVarDuty}
    initial_data::VarData
    cur_data::VarData
    moi_record::MoiVarRecord
end
const VarId = Id{Variable}

function Variable(id::VarId,
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  var_data = VarData(),
                  moi_index::MoiVarIndex = MoiVarIndex())
    return Variable(
        id, name, duty, var_data, var_data,
        MoiVarRecord(index = moi_index)
    )
end

# Attention: All getters and setters for Variable are defined
#            over AbstractVarConstr in file constraint.jl

function reset!(v::Variable)
    initial = get_initial_data(v)
    cur = get_cur_data(v)
    cur.cost = initial.cost
    cur.lower_bound = initial.lower_bound
    cur.upper_bound = initial.upper_bound
    cur.kind = initial.kind
    cur.sense = initial.sense
    cur.is_active = initial.is_active
    return
end


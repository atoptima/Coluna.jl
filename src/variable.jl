mutable struct VarData <: AbstractVcData
    cost::Float64
    lower_bound::Float64
    upper_bound::Float64
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

# Attention: Some getters and setters are defined over AbstractVcData
#            in file constraint.jl
get_cost(v::VarData) = v.cost
get_lb(v::VarData) = v.lower_bound
get_ub(v::VarData) = v.upper_bound

set_cost!(v::VarData, cost::Float64) = v.cost = cost
set_lb!(v::VarData, lb::Float64) = v.lower_bound = lb
set_ub!(v::VarData, ub::Float64) = v.upper_bound = ub

function setbound!(v::VarData, sense::ConstrSense, bound::Float64)
    if sense == Less || sense == Equal
        set_ub!(v, bound)
    elseif sense == Greater || sense == Equal
        set_lb!(v, bound)
    end
    return
end

function set_kind!(v::VarData, kind::VarKind)
    if kind == Binary
        v.kind = Binary
        (v.lower_bound < 0) && set_lb!(v, 0.0)
        (v.upper_bound > 1) && set_ub!(v, 1.0)
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

set_index!(record::MoiVarRecord, index::MoiVarIndex) = record.index = index
set_bounds!(record::MoiVarRecord, bounds::MoiVarBound) = record.bounds = bounds
set_kind!(record::MoiVarRecord, kind::MoiVarKind) = record.kind = kind

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
        id, name, duty, var_data, deepcopy(var_data),
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
    cur.inc_val = initial.inc_val
    cur.kind = initial.kind
    cur.sense = initial.sense
    cur.is_active = initial.is_active
    return
end

get_cost(v::Variable) = get_cost(v.cur_data)
get_lb(v::Variable) = get_lb(v.cur_data)
get_ub(v::Variable) = get_ub(v.cur_data)
get_kind(v::Variable) = get_kind(v.cur_data)
get_sense(v::Variable) = get_sense(v.cur_data)
get_inc_val(v::Variable) = get_inc_val(v.cur_data)
is_active(v::Variable) = is_active(v.cur_data)
is_explicit(v::Variable) = is_explicit(v.cur_data)
set_cost!(v::Variable, cost::Float64) = set_cost!(v.initial_data, cost)
set_inc_val!(v::Variable, val::Float64) = set_inc_val!(v.initial_data, val)
set_is_active!(v::Variable, is_active::Bool) =  set_is_active!(v.initial_data, is_active)
set_is_explicit!(v::Variable, is_explicit::Bool) =  set_is_explicit!(v.initial_data, is_explicit)
set_kind!(v::Variable, kind) =  set_kind!(v.initial_data, kind)
set_sense!(v::Variable, sense) = set_sense!(v.initial_data, sense)

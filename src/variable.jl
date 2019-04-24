"""
    VarData

Information that defines a state of a variable. These are the fields of a variable that might change during the solution procedure.
"""
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

# Attention: Some getters and setters of VarData are defined over AbstractVcData
#            in file varconstr.jl

get_cost(v::VarData) = v.cost
get_lb(v::VarData) = v.lower_bound
get_ub(v::VarData) = v.upper_bound

set_cost!(v::VarData, cost::Float64) = v.cost = cost
set_lb!(v::VarData, lb::Float64) = v.lower_bound = lb
set_ub!(v::VarData, ub::Float64) = v.upper_bound = ub

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
get_index(record::MoiVarRecord) = record.index
get_bounds(record::MoiVarRecord) = record.bounds
get_kind(record::MoiVarRecord) = record.kind

set_index!(record::MoiVarRecord, index::MoiVarIndex) = record.index = index
set_bounds!(record::MoiVarRecord, bounds::MoiVarBound) = record.bounds = bounds
set_kind!(record::MoiVarRecord, kind::MoiVarKind) = record.kind = kind

"""
    Variable

Representation of a variable in Coluna.
"""
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
#            over AbstractVarConstr in file varconstr.jl

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

# Helpers for getters  and stter that acces fields in a level under Variable

# -> Initial
get_init_cost(vc::AbstractVarConstr) = vc.initial_data.cost
get_init_lower_bound(vc::AbstractVarConstr) = vc.initial_data.lower_bound
get_init_upper_bound(vc::AbstractVarConstr) = vc.initial_data.upper_bound
# set_init_cost!(vc::AbstractVarConstr, cost::Float64) = vc.initial_data.cost
# set_init_lower_bound!(vc::AbstractVarConstr, lb::Float64) = vc.initial_data.lower_bound = lb
# set_init_upper_bound!(vc::AbstractVarConstr, ub::Float64) = vc.initial_data.upper_bound = ub
# -> Current
get_cur_cost(vc::AbstractVarConstr) = vc.cur_data.cost
get_cur_lower_bound(vc::AbstractVarConstr) = vc.cur_data.lower_bound
get_cur_upper_bound(vc::AbstractVarConstr) = vc.cur_data.upper_bound
set_cur_cost!(vc::AbstractVarConstr, cost::Float64) = vc.cur_data.cost = cost
set_cur_lower_bound!(vc::AbstractVarConstr, lb::Float64) = vc.cur_data.lower_bound = lb
set_cur_upper_bound!(vc::AbstractVarConstr, ub::Float64) = vc.cur_data.upper_bound = ub

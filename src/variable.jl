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

getcost(v::VarData) = v.cost
getlb(v::VarData) = v.lower_bound
getub(v::VarData) = v.upper_bound
getkind(v::VarData) = v.kind
getsense(v::VarData) = v.sense

setcost!(v::VarData, cost::Float64) = v.cost = cost
setlb!(v::VarData, lb::Float64) = v.lower_bound = lb
setub!(v::VarData, ub::Float64) = v.upper_bound = ub
setkind!(v::VarData, kind::VarKind) = v.kind = kind
setsense!(v::VarData, sense::VarSense) = v.sense = sense

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

struct Variable <: AbstractVarConstr
    id::Id{Variable}
    name::String
    duty::Type{<: AbstractVarDuty}
    initial_data::VarData
    cur_data::VarData
    moi_record::MoiVarRecord
end

function Variable(id::Id{Variable},
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  var_data = VarData(),
                  moi_index::MoiVarIndex = MoiVarIndex())
    return Variable(
        id, name, duty, var_data, var_data,
        MoiVarRecord(index = moi_index)
    )
end

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


##########################################################################
# function Variable(n::String)
#     return Variable(0, n, 0.0, -Inf, Inf, Continuous,  Free)
# end

# LocalArtVar(form_uid::Int, constr_uid::Int) = Variable(
#     form_uid, string("local_art_", constr_uid), 10, 0.0,
#    Inf, Continuous,  Positive)

# function GlobalArtVar(form_uid::Int, sense::VarSense)
#     sufix = (sense == Positive) ? "pos" : "neg"
#     name = string("glob_art_", sufix)
#     return Variable(form_uid, name, 1000.0, 0.0, Inf, Continuous,  Positive)
# end

# getform(v::Variable) = v.form_uid
# getname(v::Variable) = v.name
# getcost(v::Variable) = v.cost
# getlb(v::Variable) = v.lower_bound
# getub(v::Variable) = v.upper_bound
# getkind(v::Variable) = v.kind
# getsense(v::Variable) = v.sense

# setcost!(v::Variable, c::Float64) = v.cost += c
# setname!(v::Variable, name::String) = v.name = name
# setform!(v::Variable, uid::FormId) = v.form_uid = uid
# setlb!(v::Variable, lb::Float64) = v.lower_bound = lb
# setub!(v::Variable, ub::Float64) = v.upper_bound = ub
# setkind!(v::Variable, t::VarKind) = v.kind = t
# setsense!(v::Variable, s::VarSense) = v.sense = s

# function updatesense!(var::Variable)
#     if 0 <= var.lower_bound <= var.upper_bound
#         setsense!(var, Positive)
#     elseif var.lower_bound <= var.upper_bound <= 0
#         setsense!(var, Negative)
#     else
#         setsense!(var, Free)
#     end
#     return
# end

# function set!(v::Variable, ::MOI.ZeroOne)
#     setkind!(v, Binary)
#     setsense!(v, Positive)
#     (v.lower_bound < 0) && setlb!(v, 0.0)
#     (v.upper_bound > 1) && setub!(v, 1.0)
#     return
# end

# function set!(v::Variable, ::MOI.Integer)
#     setkind!(v, Integ)
#     return
# end

# function set!(v::Variable, s::MOI.GreaterThan)
#     lb = float(s.lower)
#     (v.lower_bound < lb) && setlb!(v, lb)
#     updatesense!(v)
#     return
# end

# function set!(v::Variable, s::MOI.EqualTo)
#     val = float(s.value)
#     setlb!(v, val)
#     setub!(v, val)
#     updatesense!(v)
#     return
# end

# function set!(v::Variable, s::MOI.LessThan)
#     ub = float(s.upper)
#     (v.upper_bound > ub) && setub!(v, ub)
#     updatesense!(v)
# end

# mutable struct VarState <: AbstractState
#     cur_cost::Float64
#     cur_lb::Float64
#     cur_ub::Float64 
#     cur_status::Status   # Active or not
#     index::MoiVarIndex # moi ref # -> moi_index
#     bd_constr_ref::Union{Nothing, MoiVarBound} # should be removed
#     kind_constr_ref::Union{Nothing, MoiVarKind} # should be removed
#     duty::Type{<: AbstractVarDuty}
#     cur_kind::VarKind
# end
# VarState() = VarState(0.0, 0.0, 0.0, Active, MoiVarIndex(), nothing, nothing, UndefinedVarDuty, Continuous)

# function VarState(Duty::Type{<: AbstractVarDuty}, var::Variable)
#     return VarState(getcost(var), getlb(var), getub(var),
#         Active, MoiVarIndex(), nothing, nothing, Duty, getkind(var))
# end

# setcost(v::VarState, cost::Float64) = v.cur_cost = cost
# getcost(v::VarState) = v.cur_cost
# getlb(v::VarState) = v.cur_lb
# getub(v::VarState) = v.cur_ub
# getstatus(v::VarState) = v.cur_status
# getmoi_index(v::VarState) = v.index
# getmoi_bdconstr(v::VarState) = v.bd_constr_ref
# getmoi_kindconstr(v::VarState) = v.kind_constr_ref
# getduty(v::VarState) = v.duty
# getkind(v::VarState) = v.cur_kind

# setcost!(v::VarState, c::Float64) = v.cur_cost = c
# setlb!(v::VarState, lb::Float64) = v.cur_lb = lb
# setub!(v::VarState, ub::Float64) = v.cur_ub = ub
# setstatus!(v::VarState, s::Status) = v.cur_status = s
# setduty!(v::VarState, d) = v.duty = d
# setmoiindex(v::VarState, index::MoiVarIndex) = v.index = index
# setmoibounds(v::VarState, bd::Union{Nothing,MoiVarBound}) = v.bd_constr_ref = bd
# setmoikind(v::VarState, kind::Union{Nothing,MoiVarKind}) = v.kind_constr_ref = kind

# vctype(::Type{<: VarState}) = Variable

# statetype(::Type{<: Variable}) = VarState

# indextype(::Type{<: Variable}) = MoiVarIndex


mutable struct Variable <: AbstractVarConstr
    form_uid::FormId
    name::String
    cost::Float64 
    lower_bound::Float64
    upper_bound::Float64 
    kind::VarKind
    sense::VarSense 
end

function Variable(n::String)
    return Variable(0, n, 0.0, -Inf, Inf, Continuous,  Free)
end

LocalArtVar(form_uid::Int, constr_uid::Int) = Variable(
    form_uid, string("local_art_", constr_uid), 10, 0.0,
   Inf, Continuous,  Positive)

function GlobalArtVar(form_uid::Int, sense::VarSense)
    sufix = (sense == Positive) ? "pos" : "neg"
    name = string("glob_art_", sufix)
    return Variable(form_uid, name, 1000.0, 0.0, Inf, Continuous,  Positive)
end

getform(v::Variable) = v.form_uid
getname(v::Variable) = v.name
getcost(v::Variable) = v.cost
getlb(v::Variable) = v.lower_bound
getub(v::Variable) = v.upper_bound
getkind(v::Variable) = v.kind
getsense(v::Variable) = v.sense

setcost!(v::Variable, c::Float64) = v.cost += c
setname!(v::Variable, name::String) = v.name = name
setform!(v::Variable, uid::FormId) = v.form_uid = uid
setlb!(v::Variable, lb::Float64) = v.lower_bound = lb
setub!(v::Variable, ub::Float64) = v.upper_bound = ub
setkind!(v::Variable, t::VarKind) = v.kind = t
setsense!(v::Variable, s::VarSense) = v.sense = s

mutable struct VarState <: AbstractState
    cur_cost::Float64
    cur_lb::Float64
    cur_ub::Float64 
    cur_status::Status   # Active or not
    index::MoiVarIndex # moi ref # -> moi_index
    bd_constr_ref::Union{Nothing, MoiVarBound} # should be removed
    kind_constr_ref::Union{Nothing, MoiVarKind} # should be removed
    duty::Type{<: AbstractVarDuty}
    cur_kind::VarKind
end
VarState() = VarState(0.0, 0.0, 0.0, Active, nothing, nothing, nothing, UndefinedVarDuty, Continuous)

function VarState(Duty::Type{<: AbstractVarDuty}, var::Variable)
    return VarState(getcost(var), getlb(var), getub(var),
        Active, nothing, nothing, nothing, Duty, getkind(var))
end

getcost(v::VarState) = v.cur_cost
getlb(v::VarState) = v.cur_lb
getub(v::VarState) = v.cur_ub
getstatus(v::VarState) = v.cur_status
getmoi_index(v::VarState) = v.index
getmoi_bdconstr(v::VarState) = v.bd_constr_ref
getmoi_kindconstr(v::VarState) = v.kind_constr_ref
getduty(v::VarState) = v.duty
getkind(v::VarState) = v.cur_kind

setcost!(v::VarState, c::Float64) = v.cur_cost = c
setlb!(v::VarState, lb::Float64) = v.cur_lb = lb
setub!(v::VarState, ub::Float64) = v.cur_ub = ub
setstatus!(v::VarState, s::Status) = v.cur_status = s
setduty!(v::VarState, d) = v.duty = d
setmoiindex(v::VarState, index::MoiVarIndex) = v.index = index
setmoibounds(v::VarState, bd::Union{Nothing,MoiVarBound}) = v.bd_constr_ref = bd
setmoikind(v::VarState, kind::Union{Nothing,MoiVarKind}) = v.kind_constr_ref = kind

function sync!(i::VarState, v::Variable)
    setlb!(i, getlb(v))
    setub!(i, getub(v))
    setcost!(i, getcost(v))
    return
end

vctype(::Type{<: VarState}) = Variable

statetype(::Type{<: Variable}) = VarState

indextype(::Type{<: Variable}) = MoiVarIndex

function set!(v::Variable, ::MOI.ZeroOne)
    setkind!(v, Binary)
    setsense!(v, Positive)
    (v.lower_bound < 0) && setlb!(v, 0.0)
    (v.upper_bound > 1) && setub!(v, 1.0)
    return
end

function set!(v::Variable, ::MOI.Integer)
    setkind!(v, Integ)
    return
end

function set!(v::Variable, s::MOI.GreaterThan)
    lb = float(s.lower)
    (v.lower_bound < lb) && setlb!(v, lb)
    (lb >= 0) && setsense!(v, Positive)
    return
end

function set!(v::Variable, s::MOI.EqualTo)
    val = float(s.value)
    setlb!(v, val)
    setub!(v, val)
    return
end

function set!(v::Variable, s::MOI.LessThan)
    ub = float(s.upper)
    (v.upper_bound > ub) && setub!(v, ub)
    (ub <= 0) && setkind!(v, Negative)
    return
end


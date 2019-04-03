mutable struct Variable <: AbstractVarConstr
    form_uid::FormId
    name::String
    cost::Float64 
    lower_bound::Float64
    upper_bound::Float64 
    kind::VarKind
    flag::Flag     # Static, Dynamic, Artificial, Implicit
    sense::VarSense 
end

function Variable(n::String)
    return Variable(0, n, 0.0, -Inf, Inf, Continuous, Static, Free)
end

LocalArtVar(form_uid::Int, constr_uid::Int) = Variable(
    form_uid, string("local_art_", constr_uid), 10, 0.0,
    1.0, Binary, Artificial, Positive
)

function GlobalArtVar(form_uid::Int, sense::VarSense)
    sufix = (sense == Positive) ? "pos" : "neg"
    name = string("glob_", sufix)
    return Variable(
        form_uid, name, 100, 0.0, 1.0, Binary, Artificial, Positive
    )
end

getform(v::Variable) = v.form_uid
getname(v::Variable) = v.name
getcost(v::Variable) = v.cost
getlb(v::Variable) = v.lower_bound
getub(v::Variable) = v.upper_bound
getkind(v::Variable) = v.kind
getsense(v::Variable) = v.sense
getflag(v::Variable) = v.flag

setcost!(v::Variable, c::Float64) = v.cost += c
setname!(v::Variable, name::String) = v.name = name
setform!(v::Variable, uid::FormId) = v.form_uid = uid
setlb!(v::Variable, lb::Float64) = v.lower_bound = lb
setub!(v::Variable, ub::Float64) = v.upper_bound = ub
setkind!(v::Variable, t::VarKind) = v.kind = t
setsense!(v::Variable, s::VarSense) = v.sense = s

mutable struct VarInfo <: AbstractVarConstrInfo
    cur_cost::Float64
    cur_lb::Float64
    cur_ub::Float64 
    cur_status::Status   # Active or not
    index::MoiVarIndex # moi ref # -> moi_index
    bd_constr_ref::Union{Nothing, MoiVarBound} # should be removed
    moi_kind::Union{Nothing, MoiVarKind} # should be removed
    duty::Type{<: AbstractVarDuty}
end

function VarInfo(Duty::Type{<: AbstractVarDuty}, var::Variable)
    return VarInfo(getcost(var), getlb(var), getub(var),
        Active, nothing, nothing, nothing, Duty)
end

getcost(v::VarInfo) = v.cur_cost
getlb(v::VarInfo) = v.cur_lb
getub(v::VarInfo) = v.cur_ub
getstatus(v::VarInfo) = v.cur_status
getmoiindex(v::VarInfo) = v.index
getmoibounds(v::VarInfo) = v.bd_constr_ref
getmoikind(v::VarInfo) = v.moi_kind
getduty(v::VarInfo) = v.duty

setcost!(v::VarInfo, c::Float64) = v.cur_cost = c
setlb!(v::VarInfo, lb::Float64) = v.cur_lb = lb
setub!(v::VarInfo, ub::Float64) = v.cur_ub = ub
setstatus!(v::VarInfo, s::Status) = v.cur_status = s
setduty!(v::VarInfo, d) = v.duty = d


vctype(::Type{<: VarInfo}) = Variable

infotype(::Type{<: Variable}) = VarInfo

indextype(::Type{<: Variable}) = MoiVarIndex

getdutytype(a::AbstractVarConstrInfo) = a.duty

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
    (ub <= 0) && settype!(v, Negative)
    return
end


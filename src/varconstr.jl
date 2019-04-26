# In file varconstrs.jl we define the functions
# that mutualize the behaviour of Variable and Constraint.

# Getters & setters for AbstractVcData

is_active(vc::AbstractVcData) = vc.is_active
is_explicit(vc::AbstractVcData) = vc.is_explicit
getkind(vc::AbstractVcData) = vc.kind
setsense(vc::AbstractVcData) = vc.sense
getincval(vc::AbstractVcData) = vc.inc_val

setincval!(vc::AbstractVcData, val::Float64) =  vc.inc_val = val
set_is_active!(vc::AbstractVcData, is_active::Bool) = vc.is_active = is_active
set_is_explicit!(vc::AbstractVcData, is_explicit::Bool) = vc.is_explicit = is_explicit
setkind!(vc::AbstractVcData, kind) = vc.kind = kind
setsense!(vc::AbstractVcData, sense) = vc.sense = sense

# Getters for AbstractVarConstr
# -> No setters because Variable and Constraint are immutable

getid(vc::AbstractVarConstr) = vc.id
getname(vc::AbstractVarConstr) = vc.name
getduty(vc::AbstractVarConstr) = vc.duty
getrecordeddata(vc::AbstractVarConstr) = vc.recorded_data
getcurdata(vc::AbstractVarConstr) = vc.cur_data
getmoirecord(vc::AbstractVarConstr) = vc.moirecord

# Helpers for getters and setters that acces fields in a level
# under Variable or Constraint

getuid(vc::AbstractVarConstr) = getuid(vc.id)
getform(vc::AbstractVarConstr) = getformuid(vc.id)

# -> Initial
getinitkind(vc::AbstractVarConstr) = vc.recorded_data.kind
getinitsense(vc::AbstractVarConstr) = vc.recorded_data.sense
getinitincval(vc::AbstractVarConstr) = vc.recorded_data.inc_val
get_init_is_active(vc::AbstractVarConstr) = vc.recorded_data.is_active
get_init_is_explicit(vc::AbstractVarConstr) = vc.recorded_data.is_explicit
# -> Current
getcurkind(vc::AbstractVarConstr) = vc.cur_data.kind
getcursense(vc::AbstractVarConstr) = vc.cur_data.sense
getcurincval(vc::AbstractVarConstr) = vc.cur_data.inc_val
get_cur_is_active(vc::AbstractVarConstr) = vc.cur_data.is_active
get_cur_is_explicit(vc::AbstractVarConstr) = vc.cur_data.is_explicit
setcurkind(vc::AbstractVarConstr, kind) = vc.cur_data.kind = kind
setcursense(vc::AbstractVarConstr, sense) = vc.cur_data.sense = sense
setcurincval(vc::AbstractVarConstr, inc_val::Float64) = vc.cur_data.inc_val = inc_val
set_cur_is_active(vc::AbstractVarConstr, is_active::Bool) = vc.cur_data.is_active = is_active
set_cur_is_explicit(vc::AbstractVarConstr, is_explicit::Bool) = vc.cur_data.is_explicit = is_explicit

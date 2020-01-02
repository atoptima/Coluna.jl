# In file varconstrs.jl we define the functions
# that mutualize the behaviour of Variable and Constraint.

# Getters for AbstractVarConstr
# -> No setters because Variable and Constraint are immutable

getid(vc::AbstractVarConstr) = vc.id
getname(vc::AbstractVarConstr) = vc.name
getduty(vc::AbstractVarConstr) = vc.duty
getcurdata(vc::AbstractVarConstr) = vc.cur_data
getmoirecord(vc::AbstractVarConstr) = vc.moirecord

# Helpers for getters and setters that acces fields in a level
# under Variable or Constraint

getuid(vc::AbstractVarConstr) = getuid(getid(vc))
getoriginformuid(vc::AbstractVarConstr) = getoriginformuid(getid(vc))
getassignedformuid(vc::AbstractVarConstr) = getassignedformuid(getid(vc))
getprocuid(vc::AbstractVarConstr) = getprocuid(getid(vc))
getsortuid(vc::AbstractVarConstr) = getsortuid(getid(vc))


# -> Initial
getperenekind(vc::AbstractVarConstr) = vc.perene_data.kind
getperenesense(vc::AbstractVarConstr) = vc.perene_data.sense
getpereneincval(vc::AbstractVarConstr) = vc.perene_data.inc_val
get_init_is_active(vc::AbstractVarConstr) = vc.perene_data.is_active
get_init_is_explicit(vc::AbstractVarConstr) = vc.perene_data.is_explicit

# -> Current
getcurkind(vc::AbstractVarConstr) = vc.cur_data.kind
getcursense(vc::AbstractVarConstr) = vc.cur_data.sense
getcurincval(vc::AbstractVarConstr) = vc.cur_data.inc_val
get_cur_is_active(vc::AbstractVarConstr) = vc.cur_data.is_active
get_cur_is_explicit(vc::AbstractVarConstr) = vc.cur_data.is_explicit
setcurkind(vc::AbstractVarConstr, kind) = vc.cur_data.kind = kind
setcursense(vc::AbstractVarConstr, sense) = vc.cur_data.sense = sense
setpereneincval!(vc::AbstractVarConstr, inc_val::Float64) = vc.perene_data.inc_val = inc_val
setcurincval!(vc::AbstractVarConstr, inc_val::Float64) = vc.cur_data.inc_val = inc_val
set_cur_is_active(vc::AbstractVarConstr, is_active::Bool) = vc.cur_data.is_active = is_active
set_cur_is_explicit(vc::AbstractVarConstr, is_explicit::Bool) = vc.cur_data.is_explicit = is_explicit

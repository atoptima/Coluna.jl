# In file varconstrs.jl we define the functions
# that mutualize the behaviour of Variable and Constraint.

# Getters for AbstractVarConstr
# -> No setters because Variable and Constraint are immutable

getid(vc::AbstractVarConstr) = vc.id
getname(vc::AbstractVarConstr) = vc.name
getduty(vc::AbstractVarConstr) = vc.duty
getmoirecord(vc::AbstractVarConstr) = vc.moirecord

# Helpers for getters and setters that acces fields in a level
# under Variable or Constraint

getuid(vc::AbstractVarConstr) = getuid(getid(vc))
getoriginformuid(vc::AbstractVarConstr) = getoriginformuid(getid(vc))
getassignedformuid(vc::AbstractVarConstr) = getassignedformuid(getid(vc))
getprocuid(vc::AbstractVarConstr) = getprocuid(getid(vc))
getsortuid(vc::AbstractVarConstr) = getsortuid(getid(vc))

# -> Initial

get_init_is_active(vc::AbstractVarConstr) = vc.perene_data.is_active
get_init_is_explicit(vc::AbstractVarConstr) = vc.perene_data.is_explicit

# -> Current

get_cur_is_active(vc::AbstractVarConstr) = vc.cur_data.is_active
get_cur_is_explicit(vc::AbstractVarConstr) = vc.cur_data.is_explicit

set_cur_is_active(vc::AbstractVarConstr, is_active::Bool) = vc.cur_data.is_active = is_active
set_cur_is_explicit(vc::AbstractVarConstr, is_explicit::Bool) = vc.cur_data.is_explicit = is_explicit

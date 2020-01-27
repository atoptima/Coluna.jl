# In file varconstrs.jl we define the functions
# that mutualize the behaviour of Variable and Constraint.

# Getters for AbstractVarConstr
# -> No setters because Variable and Constraint are immutable

getid(vc::AbstractVarConstr) = vc.id
getname(vc::AbstractVarConstr) = vc.name
getmoirecord(vc::AbstractVarConstr) = vc.moirecord

# Helpers for getters and setters that acces fields in a level
# under Variable or Constraint

getuid(vc::AbstractVarConstr) = getuid(getid(vc))
getoriginformuid(vc::AbstractVarConstr) = getoriginformuid(getid(vc))
getassignedformuid(vc::AbstractVarConstr) = getassignedformuid(getid(vc))
getprocuid(vc::AbstractVarConstr) = getprocuid(getid(vc))
getsortuid(vc::AbstractVarConstr) = getsortuid(getid(vc))


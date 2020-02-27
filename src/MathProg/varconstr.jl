# In file varconstrs.jl we define the functions
# that mutualize the behaviour of Variable and Constraint.

# Getters for AbstractVarConstr
# -> No setters because Variable and Constraint are immutable

getid(vc::AbstractVarConstr) = vc.id
getmoirecord(vc::AbstractVarConstr) = vc.moirecord

# Helpers for getters and setters that acces fields in a level
# under Variable or Constraint

getoriginformuid(vc::AbstractVarConstr) = getoriginformuid(getid(vc))

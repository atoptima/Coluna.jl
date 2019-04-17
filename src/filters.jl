# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:Id, T})::Bool

_active_(id_vc::Pair{I,T}) where {I<:Id,T <: AbstractVarConstr} = is_active(get_cur_data(id_vc[2])) == Active

_explicit_(id_vc::Pair{I,T}) where {I<:Id,T} = (getduty(id_vc[2]) isa ExplicitDuty)

_active_pricingSpVar_(id_v::Pair{VarId,Variable}) = is_active(get_cur_data(id_v[2])) == true && getduty(id_v[2]) == PricingSpVar

_explicit_(vc::AbstractVarConstr) = (getduty(vc) isa ExplicitDuty)

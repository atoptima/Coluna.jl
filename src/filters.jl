# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:Id, T})::Bool

_active_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active

_active_MspVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active &&
    getduty(getstate(id_val[1])) == MastRepPricingSpVar

_active_pricingSpVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active &&
    getduty(getstate(id_val[1])) == PricingSpVar

_explicit_(id_val::Pair{I,T}) where {I<:Id,T} = (getduty(getstate(id_val[1])) isa ExplicitDuty)

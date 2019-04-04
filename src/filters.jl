# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:Id, T})::Bool

_active_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active

_active_MspVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active &&
    getduty(getstate(id_val[1])) == MastRepPricingSpVar

_active_pricingSpVar_(id_val::Pair{I,T}) where {I<:Id,T} = getstatus(getstate(id_val[1])) == Active &&
    getduty(getstate(id_val[1])) == PricingSpVar

function _explicit_(id_val::Pair{I,T}) where {I<:Id,T}
    d = getduty(getstate(id_val[1]))
    return (d != MastRepPricingSpVar && d != MastRepPricingSetupSpVar
            && d != MastRepBendSpVar)
end
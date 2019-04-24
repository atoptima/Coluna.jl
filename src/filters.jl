# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:Id, T})::Bool

_active_masterRepOrigConstr_(id_c::Pair{ConstrId,Constraint}) = get_cur_is_active(id_c[2]) == true && get_duty(id_c[2]) <: AbstractMasterRepOriginalConstr

_active_pricingSpVar_(id_v::Pair{VarId,Variable}) = get_cur_is_active(id_v[2]) == true && get_duty(id_v[2]) <: AbstractPricingSpVar

_active_pricingMastRepSpVar_(id_v::Pair{VarId,Variable}) = get_cur_is_active(id_v[2]) == true && get_duty(id_v[2]) <: AbstractMastRepSpVar

_active_pricingMastRepSpVar_(v::Variable) = get_cur_is_active(v) == true && get_duty(v) <: AbstractMastRepSpVar

_explicit_(vc::AbstractVarConstr) = get_cur_is_explicit(vc)

_active_(vc::AbstractVarConstr) = get_cur_is_active(vc)

_explicit_(id_vc::Pair{I,T}) where {I<:Id,T<:AbstractVarConstr} = get_cur_is_explicit(id_vc[2])

_active_(id_vc::Pair{I,T}) where {I<:Id,T<:AbstractVarConstr} = get_cur_is_active(id_vc[2])

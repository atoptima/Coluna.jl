# Define default functions to use as filters

"Returns true if `id_c[2]` is a master representative of an original constraint and is currently active"
_active_master_rep_orig_constr_(id_c::Pair{ConstrId,Constraint}) = get_cur_is_active(id_c[2]) == true && getduty(id_c[2]) <: AbstractMasterOriginConstr


"Returns true if `v` is the representative of an OriginalVar"
_rep_of_orig_var_(v::Variable) = (getduty(v) isa OriginalRepresentatives)

"Returns true if `id_v[2]` is a pricing subproblem variable and is currently active"
_active_pricing_sp_var_(id_v::Pair{VarId,Variable}) = get_cur_is_active(id_v[2]) == true && getduty(id_v[2]) <: AbstractDwSpVar


_active_benders_sp_var_(id_v::Pair{VarId,Variable}) = get_cur_is_active(id_v[2]) == true && getduty(id_v[2]) <: AbstractBendSpVar

_active_benders_sp_var_(id_v::Pair{VarId,Variable}) = get_cur_is_active(id_v[2]) == true && getduty(id_v[2]) <: AbstractBendSpVar

"Returns true if `v` is a master representative of a pricing subproblem variable and is currently active"
_active_pricing_mast_rep_sp_var_(v::Variable) = get_cur_is_active(v) == true && getduty(v) <: AbstractMasterRepDwSpVar

"Returns true if `id_v[2]` is a master representative of a pricing subproblem variable and is currently active"
_active_pricing_mast_rep_sp_var_(id_v::Pair{VarId,Variable}) = _active_pricing_mast_rep_sp_var_(id_v[2])

"Returns true if `vc` is explicit"
_explicit_(vc::AbstractVarConstr) = get_cur_is_explicit(vc)

"Returns true if `vc` is currently active"
_active_(vc::AbstractVarConstr) = get_cur_is_active(vc)

"Returns true if `id_vc[2]` is explicit"
_explicit_(id_vc::Pair{I,T}) where {I<:Id,T<:AbstractVarConstr} = _explicit_(id_vc[2])

"Returns true if `id_vc[2]` is currently active"
_active_(id_vc::Pair{I,T}) where {I<:Id,T<:AbstractVarConstr} = _active_(id_vc[2])

"Returns true if `vc` is currently active and is explicit"
_active_explicit_(vc::AbstractVarConstr) = (get_cur_is_active(vc) && get_cur_is_explicit(vc))

"Returns true if `id_vc[2]` is currently active and is explicit"
_active_explicit_(id_vc::Pair{I,T}) where {I<:Id,T<:AbstractVarConstr} = (get_cur_is_active(id_vc[2]) && get_cur_is_explicit(id_vc[2]))
# Define default functions to use as filters

"Returns true if `c` is a master representative of an original constraint and is currently active"
_active_master_rep_orig_constr_(c::Constraint) = get_cur_is_active(c) == true && getduty(c) <= AbstractMasterOriginConstr

_active_BendSpMaster_constr_(c::Constraint) = get_cur_is_active(c) == true && getduty(c) <= AbstractBendSpMasterConstr

"Returns true if `v` is the representative of an OriginalVar"
_rep_of_orig_var_(v::Variable) = isanOriginalRepresentatives(getduty(v))

_sp_var_rep_in_orig_(v::Variable) = getduty(v) <= DwSpPricingVar || getduty(v) <= DwSpSetupVar

"Returns true if `v` is a pricing subproblem variable and is currently active"
_active_pricing_sp_var_(v::Variable) = get_cur_is_active(v) == true && getduty(v) <= AbstractDwSpVar

"Returns true if `v` is a benders subproblem variable and is currently active"
_active_BendSpSlackFirstStage_var_(v::Variable) = get_cur_is_active(v) == true && getduty(v) <= BendSpSlackFirstStageVar

_active_firststage_sp_var_(v::Variable) = get_cur_is_active(v) == true && getduty(v) <= BendSpSlackFirstStageVar

"Returns true if `v` is a master representative of a pricing subproblem variable and is currently active"
_active_pricing_mast_rep_sp_var_(v::Variable) = get_cur_is_active(v) == true && getduty(v) <= AbstractMasterRepDwSpVar

"Returns true if `vc` is explicit"
_explicit_(vc::AbstractVarConstr) = get_cur_is_explicit(vc)

"Returns true if `vc` is currently active"
_active_(vc::AbstractVarConstr) = get_cur_is_active(vc)

"Returns true if `vc` is currently active and is explicit"
_active_explicit_(vc::AbstractVarConstr) = (get_cur_is_active(vc) && get_cur_is_explicit(vc))


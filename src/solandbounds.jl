mutable struct SolsAndBounds
    alg_inc_ip_primal_bound::Float64
    alg_inc_lp_primal_bound::Float64
    alg_inc_ip_dual_bound::Float64
    alg_inc_lp_dual_bound::Float64
    alg_inc_lp_primal_sol::VarMembership
    alg_inc_ip_primal_sol::VarMembership
    alg_inc_lp_dual_sol::ConstrMembership
    is_alg_inc_ip_primal_bound_updated::Bool
end

SolsAndBounds(constrs::ConstrDict, vars::VarDict) =
    SolsAndBounds(Inf, Inf, -Inf, -Inf,
                  VarMembership(vars),
                  VarMembership(vars),
                  ConstrMembership(constrs),
                  false)

# ### Methods of SolsAndBounds
# function update_primal_lp_bound(incumbents::SolsAndBounds,
#                                 newbound::Float64)
#     if newbound < incumbents.alg_inc_lp_primal_bound
#         incumbents.alg_inc_lp_primal_bound = newbound
#     end
# end

# function update_primal_ip_incumbents(incumbents::SolsAndBounds,
#                                      newbound::Float64,
#                                      var_membership::VarMemberDict)
#     if newbound < incumbents.alg_inc_ip_primal_bound
#         incumbents.alg_inc_ip_primal_bound = newbound
#         incumbents.alg_inc_ip_primal_sol = copy(var_membership)
#         incumbents.is_alg_inc_ip_primal_bound_updated = true
#     end
# end

# function update_primal_lp_incumbents(incumbents::SolsAndBounds,
#                                      newbound::Float64,
#                                      var_membership::VarMemberDict)
#     if newbound < incumbents.alg_inc_lp_primal_bound
#         incumbents.alg_inc_lp_primal_bound = newbound
#         incumbents.alg_inc_lp_primal_sol = copy(var_membership)
#     end
# end

# function update_dual_lp_bound(incumbents::SolsAndBounds,
#                               newbound::Float64)
#     if newbound > incumbents.alg_inc_lp_dual_bound
#         incumbents.alg_inc_lp_dual_bound = newbound
#     end
# end

# function update_dual_ip_bound(incumbents::SolsAndBounds,
#                               newbound::Float64)
#     new_ip_bound = newbound
#     # new_ip_bound = ceil(newbound) # TODO ceil if objective is integer
#     if new_ip_bound > incumbents.alg_inc_ip_dual_bound
#         incumbents.alg_inc_ip_dual_bound = new_ip_bound
#     end
# end

# function update_dual_lp_incumbents(incumbents::SolsAndBounds,
#                                    newbound::Float64,
#                                    constr_membership::ConstrMemberDict)
#     if newbound > incumbents.alg_inc_lp_dual_bound
#         incumbents.alg_inc_lp_dual_bound = newbound
#         incumbents.alg_inc_lp_dual_sol = copy(constr_membership)
#     end
# end

mutable struct Incumbents{S}
    ip_primal_sol::PrimalSolution{S}
    ip_dual_bound::DualBound{S}
    lp_primal_sol::PrimalSolution{S}
    lp_dual_sol::DualSolution{S}
end

function Incumbents{S}() where {S<:AbstractObjSense}
    return Incumbents{S}(
        PrimalSolution{S}(), DualBound{S}(),
        PrimalSolution{S}(), DualSolution{S}()
    )
end

get_ip_primal_sol(i::Incumbents) = i.ip_primal_sol
get_lp_primal_sol(i::Incumbents) = i.lp_primal_sol
get_lp_dual_sol(i::Incumbents) = i.lp_dual_sol

get_ip_primal_bound(i::Incumbents) = getbound(i.ip_primal_sol)
get_ip_dual_bound(i::Incumbents) = i.ip_dual_bound
get_lp_primal_bound(i::Incumbents) = getbound(i.lp_primal_sol)
get_lp_dual_bound(i::Incumbents) = getbound(i.lp_dual_sol)

ip_gap(i::Incumbents) = gap(get_ip_primal_bound(i), get_ip_dual_bound(i))
lp_gap(i::Incumbents) = gap(get_lp_primal_bound(i), get_lp_dual_bound(i))


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

function update_primal_lp_sol!(inc::Incumbents{S},
                          lp_primal_sol::PrimalSolution{S}) where {S}
    if isbetter(getbound(lp_primal_sol), getbound(inc.lp_primal_sol))
        inc.lp_primal_sol = lp_primal_sol
    end
end

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

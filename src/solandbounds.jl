mutable struct SolsAndBounds
    alg_inc_ip_primal_bound::Float64
    alg_inc_lp_primal_bound::Float64
    alg_inc_ip_dual_bound::Float64
    alg_inc_lp_dual_bound::Float64
    alg_inc_lp_primal_sol::Membership{VarState}
    alg_inc_ip_primal_sol::Membership{VarState}
    alg_inc_lp_dual_sol::Membership{ConstrState}
    is_alg_inc_ip_primal_bound_updated::Bool
end

SolsAndBounds() = SolsAndBounds(Inf, Inf, -Inf, -Inf,
                                Membership(Variable),
                                Membership(Variable),
                                Membership(Constraint),
                                false)

### Methods of SolsAndBounds
function update_primal_lp_bound(incumbents::SolsAndBounds,
                                newbound::Float64)
    if newbound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newbound
    end
end

function update_primal_ip_incumbents(incumbents::SolsAndBounds,
                                     newbound::Float64,
                                     var_membership::Membership{VarState})
    if newbound < incumbents.alg_inc_ip_primal_bound
        incumbents.alg_inc_ip_primal_bound = newbound
        incumbents.alg_inc_ip_primal_sol = deepcopy(var_membership)
        incumbents.is_alg_inc_ip_primal_bound_updated = true
    end
end

function update_primal_lp_incumbents(incumbents::SolsAndBounds,
                                     newbound::Float64,
                                     var_membership::Membership{VarState})
    if newbound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newbound
        incumbents.alg_inc_lp_primal_sol = deepcopy(var_membership)
    end
end

function update_dual_lp_bound(incumbents::SolsAndBounds,
                              newbound::Float64)
    if newbound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newbound
    end
end

function update_dual_ip_bound(incumbents::SolsAndBounds,
                              newbound::Float64)
    new_ip_bound = newbound
    # new_ip_bound = ceil(newbound) # TODO ceil if objective is integer
    if new_ip_bound > incumbents.alg_inc_ip_dual_bound
        incumbents.alg_inc_ip_dual_bound = new_ip_bound
    end
end

function update_dual_lp_incumbents(incumbents::SolsAndBounds,
                                   newbound::Float64,
                                   constr_membership::Membership{ConstrState})
    if newbound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newbound
        incumbents.alg_inc_lp_dual_sol = deepcopy(constr_membership)
    end
end

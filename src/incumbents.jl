mutable struct Incumbents{S}
    ip_primal_sol::PrimalSolution{S}
    ip_dual_bound::DualBound{S}
    lp_primal_sol::PrimalSolution{S}
    lp_dual_sol::DualSolution{S}
end

"""
    Incumbents(objsense)

"""
function Incumbents(S::Type{<: AbstractObjSense})
    return Incumbents{S}(
        PrimalSolution(S), DualBound(S),
        PrimalSolution(S), DualSolution(S)
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

function set_primal_ip_sol!(inc::Incumbents{S},
                            sol::PrimalSolution{S}) where {S}
    if isbetter(getbound(sol), getbound(inc.ip_primal_sol))
        inc.ip_primal_sol = sol
        return true
    end
    return false
end

function set_primal_lp_sol!(inc::Incumbents{S},
                            sol::PrimalSolution{S}) where {S}
    if isbetter(getbound(sol), getbound(inc.lp_primal_sol))
        inc.lp_primal_sol = sol
        return true
    end
    return false
end

function set_dual_ip_bound!(inc::Incumbents{S},
                            new_bound::DualBound{S}) where {S}
    if isbetter(new_bound, get_ip_dual_bound(inc))
        inc.ip_dual_bound = new_bound
        return true
    end
    return false
end

function set_dual_lp_sol!(inc::Incumbents{S},
                            sol::DualSolution{S}) where {S}
    if isbetter(getbound(sol), getbound(inc.lp_dual_sol))
        inc.lp_dual_sol = sol
        return true
    end
    return false
end
struct PrimalSolution
    value::Float64
    members::VarMembership
end

function PrimalSolution()
    return PrimalSolution(Inf, VarMembership())
end

#function PrimalSolution(value::Float64, sol::VarMembership)
#    return PrimalSolution(value, sol)
#end

struct DualSolution
    value::Float64
    members::ConstrMembership
end

function DualSolution()
    return DualSolution(-Inf, ConstrMembership())
end

function compute_original_cost(sol::PrimalSolution, form::Formulation)
    cost = 0.0
    for (var_uid, val) in sol.members
        var = getvar(form,var_uid)
        cost += var.cost * val
    end
    @logmsg LogLevel(-4) string("intrinsic_cost = ",cost)
    return cost
end

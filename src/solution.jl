struct PrimalSolution
    value::Float64
    var_members::VarMembership
    next::Union{Nothing,PrimalSolution}
end

function PrimalSolution()
    return PrimalSolution(Inf, VarMembership(), nothing)
end

struct DualSolution
    value::Float64
    constr_members::ConstrMembership
end

function DualSolution()
    return DualSolution(-Inf, ConstrMembership())
end

function compute_original_cost(sol::PrimalSolution, form::Formulation)
    cost = 0.0
    for (var_uid, val) in sol.var_members
        var = getvar(form,var_uid)
        cost += var.cost * val
    end
    @logmsg LogLevel(-4) string("intrinsic_cost = ",cost)
    return cost
end

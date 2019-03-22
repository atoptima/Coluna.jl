### Create Solution and DualSolution
### Remove @hl

@hl mutable struct PrimalSolution
    cost::Float #TODO clarify if curcost?
    var_val_map::Dict{Variable, Float}
end

function compute_original_cost(sol::PrimalSolution)
    cost = 0.0
    for (var, val) in sol.var_val_map
        cost += var.cost_rhs * val
    end
    @logmsg LogLevel(-4) string("intrinsic_cost = ",cost)
    return cost
end

@hl mutable struct DualSolution
    cost::Float
    constr_val_map::Dict{Constraint, Float}
end


function PrimalSolutionBuilder()
    return (Inf, Dict{Variable, Float}())
end

function DualSolutionBuilder()
    return (-Inf, Dict{Constraint, Float}())
end

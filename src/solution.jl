### Create Solution and DualSolution
### Remove @hl

@hl mutable struct PrimalSolution
    cost::Float
    var_val_map::Dict{Variable, Float}
end

@hl mutable struct DualSolution
    cost::Float
    var_val_map::Dict{Constraint, Float}
end


function PrimalSolutionBuilder()
    return (Inf, Dict{Variable, Float}())
end

function DualSolutionBuilder()
    return (-Inf, Dict{Constraint, Float}())
end

### Create Solution and DualSolution
### Remove @hl

@hl type Solution
    cost::Float
    var_val_map::Dict{Variable, Float}
end

function SolutionBuilder()
    return (0.0, Dict{Variable, Float}())
end

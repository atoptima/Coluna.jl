struct PrimalSolution
    value::Float64
    members::Membership{Variable}
end

function PrimalSolution()
    return PrimalSolution(Inf, Membership(Variable))
end

#function PrimalSolution(value::Float64, sol::Membership{Variable})
#    return PrimalSolution(value, sol)
#end

struct DualSolution
    value::Float64
    members::Membership{Constraint}
end

function DualSolution()
    return DualSolution(-Inf, Membership(Constraint))
end


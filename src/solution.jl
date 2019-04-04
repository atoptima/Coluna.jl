struct PrimalSolution
    value::Float64
    members::Membership{VarState}
end

function PrimalSolution()
    return PrimalSolution(Inf, Membership(Variable))
end

#function PrimalSolution(value::Float64, sol::Membership{VarState})
#    return PrimalSolution(value, sol)
#end

struct DualSolution
    value::Float64
    members::Membership{ConstrState}
end

function DualSolution()
    return DualSolution(-Inf, Membership(Constraint))
end


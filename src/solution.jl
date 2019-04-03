struct PrimalSolution
    value::Float64
    members::Membership{VarInfo}
end

function PrimalSolution()
    return PrimalSolution(Inf, Membership(Variable))
end

#function PrimalSolution(value::Float64, sol::Membership{VarInfo})
#    return PrimalSolution(value, sol)
#end

struct DualSolution
    value::Float64
    members::Membership{ConstrInfo}
end

function DualSolution()
    return DualSolution(-Inf, Membership(Constraint))
end


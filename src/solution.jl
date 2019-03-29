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


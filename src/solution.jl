struct PrimalSolution
    value::Float64
    members::VarMemberDict
end

function PrimalSolution()
    return PrimalSolution(Inf, VarMemberDict())
end

#function PrimalSolution(value::Float64, sol::VarMemberDict)
#    return PrimalSolution(value, sol)
#end

struct DualSolution
    value::Float64
    members::ConstrMemberDict
end

function DualSolution()
    return DualSolution(-Inf, ConstrMemberDict())
end


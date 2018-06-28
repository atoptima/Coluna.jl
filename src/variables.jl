@hl type Variable <: VarConstr
    # ```
    # Flag telling whether or not the variable is fractional.
    # ```
    moiindex::MOI.VariableIndex


    # ```
    # To represent global lower bound on  variable primal value or on constraint dual value
    # ```
    lowerbound::Float


    # ```
    # To represent global upper bound on variable primal value or on constraint dual value
    # ```
    upperbound::Float

    curlb::Float
    curub::Float
end

VariableBuilder(var::Variable) = tuplejoin(VarConstrBuilder(var), (MOI.VariableIndex(-1),
                                                                   -Inf, Inf, -Inf, Inf))
function VariableBuilder( problem::P, name::String, costrhs::Float, sense::Char, vc_type::Char, flag::Char, 
                          directive::Char, priority::Float, lowerBound::Float, upperBound::Float) where P
    return tuplejoin(VarConstrBuilder( problem, name, costrhs, sense, vc_type, flag, directive, priority),
                      MOI.VariableIndex(-1), lowerBound, upperBound, -Inf, Inf)
end

@hl type SubProbVar{M} <: Variable
    masterprob::M

    # ```
    # To represent global upper bound on sp variable primal value
    # ```
    globalub::Float

    # ```
    # To represent global lower bound on sp variable primal value
    # ```
    globallb::Float

    # ```
    # Current global bound values
    # ```
    curglobalub::Float
    curgloballb::Float

    # ```
    # Represents the master membership in the master constraints as a map where:
    # - The key is the index of the master constraint including this as member,
    # - The value is the corresponding coefficient.
    # ```
    masterconstrcoefmap::Dict{Int, Float}

    # ```
    # Represents the master membership in column solutions as map where:
    # - The key is the index of a column whose solutions includes this as member,
    # - The value is the variable value of this in the corresponding pricing solution.
    # ```
    mastercolcoefmap::Dict{Int, Float}
end

function SubProbVarBuilder(problem::P, name::String, costrhs::Float, sense::Char, vc_type::Char, flag::Char, 
                           directive::Char, priority::Float, lowerBound::Float, upperBound::Float, masterproblem::M, 
                           globallb::Float, globalub::Float, curgloballb::Float, curglobalub::Float) where {P,M}
    return tuplejoin(VariableBuilder( problem, name, costrhs, sense, vc_type, flag, directive, priority, 
                                      lowerBound, upperBound ),
                      masterproblem, globallb, globalub, curgloballb, curglobalub, 
                      Dict{Int,Float}(), Dict{Int,Float}())
end

@hl type MasterVar <: Variable
    # ```
    # Holds the contribution of the master variable in the lagrangian dual bound
    # ```
    dualBoundContrib::Float
end

MasterVarBuilder(v::Variable) = tuplejoin(VariableBuilder(v), (0.0,))
function MasterVarBuilder( problem::P, name::String, costrhs::Float, sense::Char, vc_type::Char, flag::Char, 
                           directive::Char, priority::Float, lowerBound::Float, upperBound::Float ) where P
    return tuplejoin(VariableBuilder( problem, name, costrhs, sense, vc_type, flag, directive, priority, 
                                      lowerBound, upperBound), 0.0)
end

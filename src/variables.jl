@hl type SubprobVar{M} <: Variable
    masterprob::M

    # ```
    # To represent global upper bound on sp variable primal value
    # ```
    global_ub::Float

    # ```
    # To represent global lower bound on sp variable primal value
    # ```
    global_lb::Float

    # ```
    # Current global bound values
    # ```
    cur_global_ub::Float
    cur_global_lb::Float

    # ```
    # Represents the master membership in the master constraints as a map where:
    # - The key is the index of the master constraint including this as member,
    # - The value is the corresponding coefficient.
    # ```
    master_constr_coef_map::Dict{Constraint, Float} # Constraint -> MasterConstr

    # ```
    # Represents the master membership in column solutions as map where:
    # - The key is the index of a column whose solutions includes this as member,
    # - The value is the variable value in the corresponding pricing solution.
    # ```
    master_col_coef_map::Dict{Variable, Float} # Variable -> MasterColumn
end

function SubprobVarBuilder(problem::P, name::String, costrhs::Float, sense::Char,
        vc_type::Char, flag::Char, directive::Char, priority::Float, 
        lowerBound::Float, upperBound::Float, masterproblem::M, globallb::Float, 
        globalub::Float, curgloballb::Float, curglobalub::Float) where {P,M}
        
    return tuplejoin(VariableBuilder(problem, name, costrhs, sense, vc_type, flag,
            directive, priority, lowerBound, upperBound), masterproblem, globallb, 
            globalub, curgloballb, curglobalub, Dict{Constraint,Float}(), 
            Dict{Variable,Float}())
end

@hl type MasterVar <: Variable
    # ```
    # Holds the contribution of the master variable in the lagrangian dual bound
    # ```
    dualBoundContrib::Float
end

MasterVarBuilder(v::Variable) = tuplejoin(VariableBuilder(v), (0.0,))

function MasterVarBuilder( problem::P, name::String, costrhs::Float, sense::Char,
        vc_type::Char, flag::Char, directive::Char, priority::Float, 
        lowerBound::Float, upperBound::Float ) where P
        
    return tuplejoin(VariableBuilder( problem, name, costrhs, sense, vc_type, 
            flag, directive, priority, lowerBound, upperBound), 0.0)
end

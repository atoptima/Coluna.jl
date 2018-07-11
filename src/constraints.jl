@hl type Constraint <: VarConstr
    moi_index::MOI.ConstraintIndex{F,S} where {F,S}
    set_type::Type{<:MOI.AbstractSet}
end

function ConstraintBuilder(problem::P, name::String, cost_rhs::Float, sense::Char, 
                           vc_type::Char, flag::Char) where P
    if sense == 'G'
        set_type = MOI.GreaterThan
    elseif sense == 'L'
        set_type = MOI.LessThan
    elseif sense == 'E'
        set_type = MOI.EqualTo
    else
        error("Sense $sense is not supported")
    end

    return tuplejoin(VarConstrBuilder(problem, name, cost_rhs, sense, vc_type, 
            flag, 'U', 1.0), 
            MOI.ConstraintIndex{MOI.ScalarAffineFunction,set_type}(-1), set_type)
end

@hl type MasterConstr <: Constraint
    # ```
    # Represents the membership of subproblem variables as a map where:
    # - The key is the index of the subproblem variable involved in this as member,
    # - The value is the corresponding coefficient.
    # ```
    subprob_var_coef_map::Dict{Int, Float}

    # ```
    # Represents the membership of pure master variables as a map where:
    # - The key is the index of the pure master variable involved in this as member,
    # - The value is the corresponding coefficient.
    # ```
    # puremastvarcoefmap::Dict{Int, Float}

    # ```
    # Represents the membership of master comlumns as a map where:
    # - The key is the index of the master columns involved in this as member,
    # - The value is the corresponding coefficient.
    # ```
    mast_col_coef_map::Dict{Int,Float}

end

function MasterConstrBuilder(problem::P, name::String, cost_rhs::Float, sense::Char,
                             vc_type::Char, flag::Char) where P
    return tuplejoin(ConstraintBuilder(problem, name, cost_rhs, sense, vc_type, flag),
                     Dict{Int,Float}(), Dict{Int,Float}())
end

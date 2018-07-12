@hl type MasterConstr <: Constraint
    # ```
    # Represents the membership of subproblem variables as a map where:
    # - The key is the index of the subproblem variable involved in this as member,
    # - The value is the corresponding coefficient.
    # ```
    subprob_var_coef_map::Dict{SubprobVar, Float}

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
    mast_col_coef_map::Dict{Variable,Float} # Variable -> MasterColumn

end

function MasterConstrBuilder(counter::VarConstrCounter, name::String,
        cost_rhs::Float, sense::Char, vc_type::Char, flag::Char)
    return tuplejoin(ConstraintBuilder(counter, name, cost_rhs, sense, vc_type, flag),
                     Dict{SubprobVar,Float}(), Dict{Variable,Float}())
end

@hl type BranchConstr <: Constraint
    depth_when_generated::Int
end

function BranchConstrBuilder(counter::VarConstrCounter, name::String,
    cost_rhs::Float, sense::Char)
    return tuplejoin(ConstraintBuilder(counter, name, cost_rhs, sense, ' ', 's'),
                     0)
end

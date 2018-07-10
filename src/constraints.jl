@hl type Constraint <: VarConstr
    moiindex::MOI.ConstraintIndex{F,S} where {F,S}
    settype::Type{<:MOI.AbstractSet}
end

function ConstraintBuilder(problem::P, name::String, costrhs::Float, sense::Char, 
                           vc_type::Char, flag::Char) where P
    if sense == 'G'
        settype = MOI.GreaterThan
    elseif sense == 'L'
        settype = MOI.LessThan
    elseif sense == 'E'
        settype = MOI.EqualTo
    else
        error("Sense $sense is not supported")
    end

    return tuplejoin(VarConstrBuilder(problem, name, costrhs, sense, vc_type, 
            flag, 'U', 1.0), 
            MOI.ConstraintIndex{MOI.ScalarAffineFunction,settype}(-1), settype)
end

@hl type MasterConstr <: Constraint
    # ```
    # Represents the membership of subproblem variables as a map where:
    # - The key is the index of the subproblem variable involved in this as member,
    # - The value is the corresponding coefficient.
    # ```
    subprobvarcoefmap::Dict{Int, Float}

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
    mastcolcoefmap::Dict{Int,Float}

end

function MasterConstrBuilder(problem::P, name::String, costrhs::Float, sense::Char,
                             vc_type::Char, flag::Char) where P
    return tuplejoin(ConstraintBuilder(problem, name, costrhs, sense, vc_type, flag),
                     Dict{Int,Float}(), Dict{Int,Float}())
end

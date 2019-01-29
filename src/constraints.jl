@hl mutable struct MasterConstr <: Constraint
    # ```
    # Represents the membership of a subproblem variable as a map where:
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

    return tuplejoin(ConstraintBuilder(counter, name, cost_rhs, sense, vc_type,
            flag), Dict{SubprobVar,Float}(), Dict{Variable,Float}())
end

@hl mutable struct ConvexityConstr <: MasterConstr
end

function ConvexityConstrBuilder(counter::VarConstrCounter, name::String,
        cost_rhs::Float, sense::Char, vc_type::Char, flag::Char)

    return MasterConstrBuilder(counter, name, cost_rhs, sense, vc_type, flag)
end

@hl mutable struct MasterBranchConstr{
    T} <: MasterConstr
    depth_when_generated::Int
    branch_var::T
end

function MasterBranchConstrBuilder(counter::VarConstrCounter, name::String,
        rhs::Float, sense::Char, depth::Int, branch_var::Variable)

    return tuplejoin(MasterConstrBuilder(counter, name, rhs, sense, 'C', 'd'),
                     depth, branch_var)
end

function MasterBranchConstrConstructor(counter::VarConstrCounter, name::String,
    rhs::Float, sense::Char, depth::Int, branch_var::MasterVar)

    constr = MasterBranchConstr(counter, name, rhs, sense, depth, branch_var)
    constr.status = Unsuitable

    constr.member_coef_map[constr.branch_var] = 1.0
    constr.branch_var.member_coef_map[constr] = 1.0

    return constr
end

function MasterBranchConstrConstructor(counter::VarConstrCounter, name::String,
    rhs::Float, sense::Char, depth::Int, branch_var::SubprobVar)

    constr = MasterBranchConstr(counter, name, rhs, sense, depth, branch_var)
    constr.status = Unsuitable

    constr.subprob_var_coef_map[constr.branch_var] = 1.0
    constr.branch_var.master_constr_coef_map[constr] = 1.0

    for col_coef in branch_var.master_col_coef_map
        constr.member_coef_map[col_coef[1]] = col_coef[2]
    end

    return constr
end

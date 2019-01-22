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

@hl mutable struct BranchConstr <: Constraint
    depth_when_generated::Int
end

function BranchConstrBuilder(counter::VarConstrCounter, name::String,
        rhs::Float, sense::Char, depth::Int)

    return tuplejoin(ConstraintBuilder(counter, name, rhs, sense, ' ', 'd'),
                     depth)
end

function BranchConstrConstructor(counter::VarConstrCounter, name::String,
    rhs::Float, sense::Char, depth::Int, var::Variable)

    constr = BranchConstr(counter, name, rhs, sense, depth)
    constr.member_coef_map[var] = 1.0
    var.member_coef_map[constr] = 1.0

    return constr
end

@hl mutable struct SubprobBranchConstr <: BranchConstr
    branch_var::SubprobVar
end

function SubprobBranchConstrBuilder(counter::VarConstrCounter, name::String,
        rhs::Float, sense::Char, depth::Int, branch_var::SubprobVar)

    return tuplejoin(BranchConstrBuilder(counter, name, rhs, sense, depth),
                     branch_var)
end

function BranchConstrConstructor(counter::VarConstrCounter, name::String,
    rhs::Float, sense::Char, depth::Int, var::SubprobVar)

    constr = SubprobBranchConstr(counter, name, rhs, sense, depth, var)
    for coef_val in var.master_col_coef_map
        constr.member_coef_map[coef_val[1]] = coef_val[2]
    end
    var.master_constr_coef_map[constr] = 1.0 # TODO: review this because the constraint may be inactive in other nodes

    #global c_ = constr
    #global v_ = var
    #SimpleDebugger.@bkp

    return constr
end

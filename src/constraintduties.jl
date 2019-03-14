mutable struct Original <: AbstractConstrDuty
    moi_def::MoiConstrDef # explicit Constr
    rep_in_reform::Constraint # if any
end

mutable struct PureMasterConstr <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Constraint
    #data::ANY
end

mutable struct MasterConstr <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Constraint
    subprob_var_coef_map::Dict{Variable, Float64}
    mast_col_coef_map::Dict{Variable,Float64} # Variable -> MasterColumn
end

mutable struct Convexity <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
end

mutable struct MasterBranchConstr{T} <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Constraint
    branch_var::T
    depth_when_generated::Int
    subprob_var_coef_map::Dict{Variable, Float64}
    mast_col_coef_map::Dict{Variable,Float64} # Variable -> MasterColumn
end

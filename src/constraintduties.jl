mutable struct ExplicitOriginalConstr <: AbstractConstrDuty
    rep_in_reform::Constraint # if any
    moi_def::MoiConstrDef 
end

mutable struct ExplicitOriginalBranchingConstr <: AbstractConstrDuty
    rep_in_reform::Constraint # if any
    moi_def::MoiConstrDef 
end

mutable struct ExplicitPureMasterConstr <: AbstractConstrDuty
    original_rep::Constraint{ExplicitOriginalConstr}
    moi_def::MoiVarDef
    #data::ANY
end

mutable struct ExplicitMasterConstr <: AbstractConstrDuty
    original_rep::Constraint{ExplicitOriginalConstr}
    moi_def::MoiVarDef 
#    subprob_var_membership::Membership{Variable}
#    mast_col_membership::Membership{Variable} # Variable -> MasterColumn
end

mutable struct ExplicitConvexityConstr <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
end

mutable struct ExplicitMasterBranchConstr{T} <: AbstractConstrDuty
    original_rep::Constraint{ExplicitOriginalBranchingConstr}
    moi_def::MoiVarDef # explicit var
    branch_var::T
    depth_when_generated::Int
#    mast_col_membership::Membership{Variable} # Variable -> MasterColumn
end

mutable struct PricingSpRepMastBranchConstr{T} <: AbstractConstrDuty
    original_rep::Constraint{ExplicitOriginalBranchingConstr}
    master_rep::Constraint{ExplicitMasterBranchConstr}
    moi_def::MoiVarDef # explicit var
 #   subprob_var_membership::Membership{Variable}
end

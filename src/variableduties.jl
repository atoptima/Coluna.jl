mutable struct OriginalVar <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    rep_in_reform::Variable  # if any
end

mutable struct PureMasterVar <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Variable
    #data::ANY
end

mutable struct MasterCol <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    #data::ANY
end

mutable struct MastArtVar <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    is_local::Bool
    associated_constr::Constraint # defined if local artifical val
end

mutable struct PricingSpVar <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Variable
    master_constr_membership::ConstrMembership # Constraint -> MasterConstr
    master_col_membership::VarMembership # Variable -> MasterColumn
end

mutable struct BendersSpVar <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Variable
    #data::ANY
end

mutable struct BlockGenSpVar <: AbstractVarDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Variable
    #data::ANY
end


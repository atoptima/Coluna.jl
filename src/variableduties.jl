#==
mutable struct ExplicitOriginVar <: AbstractVarDuty
    rep_in_reform::Variable  # if any
    moi_def::MoiVarDef
end

mutable struct ExplicitPureMastVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    moi_def::MoiVarDef 
    #data::ANY
end

mutable struct ExplicitMastCol <: AbstractVarDuty
    moi_def::MoiVarDef 
    pricing_sp_var_membership::Membership{Variable} # Variable -> PricingSpVar
    #data::ANY
end

mutable struct ExplicitMastArtVar <: AbstractVarDuty
    is_local::Bool
    associated_constr::Constraint # defined if local artifical val
    moi_def::MoiVarDef 
end

mutable struct MastRepPricingSpVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    master_constr_membership::Membership{Constraint} # Constraint -> MasterConstr
    rep_in_pricing_sp::Variable{AbstractVarDuty} # must be of type ExplicitPricingSpVar 
end

mutable struct ExplicitPricingSpVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    rep_in_master::Variable{MastRepPricingSpVar}  
    moi_def::MoiVarDef 
    master_col_membership::Membership{Variable} # Variable -> MasterColumn
end

mutable struct MastRepBendSpVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    rep_in_benders_sp::Variable{AbstractVarDuty} # must be of type ExplicitBendersSpVar
    #data::ANY
end

mutable struct ExplicitBendersSpVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    rep_in_master::Variable{MastRepBendSpVar}  
    moi_def::MoiVarDef 
    #data::ANY
end


mutable struct ExplicitBlockGenSpVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    rep_in_master::Variable{AbstractVarDuty}  # must be of type ExplicitMastRepBlockSpVar
    moi_def::MoiVarDef
    #data::ANY
end

mutable struct ExplicitMastRepBlockSpVar <: AbstractVarDuty
    original_rep::Variable{ExplicitOriginVar}
    rep_in_blockgen_sp::Variable{ExplicitBlockGenSpVar} 
    moi_def::MoiVarDef 
    #data::ANY
end
==#



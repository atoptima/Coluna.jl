include("varconstr.jl")

struct Formulation
end

struct Constraint
end

struct Variable{DutyType <: AbstractVarDuty}
    uid::Int # unique id
    name::String
    duty::DutyType
    formulation::Formulation
    cost::Float64
    # ```
    # sense : 'P' = positive
    # sense : 'N' = negative
    # sense : 'F' = free
    # ```
    sense::Char
    # ```
    # 'C' = continuous,
    # 'B' = binary, or
    # 'I' = integer
    vc_type::Char
    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # 'a' for artificial VarConstr.
    # ```
    flag::Char
    lower_bound::Float64
    upper_bound::Float64
    
    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    # ```
    # 'U' or 'D'
    # ```
    directive::Char
    # ```
    # A higher priority means that var is selected first for branching or diving
    # ```
    priority::Float64
    status::VCSTATUS

        # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    member_coef_map::Dict{Constraint, Float64}
end

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
    master_constr_coef_map::Dict{Constraint, Float} # Constraint -> MasterConstr
    master_col_coef_map::Dict{Variable, Float} # Variable -> MasterColumn
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




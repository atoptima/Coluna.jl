include("varconstr.jl")


struct Constraint{DutyType <: AbstractConstrDuty}
    uid::Int  # unique id
    name::String
    duty::DutyType
    formulation::Formulation
    vc_ref::Int
    rhs::Float64
    # ```
    # sense : 'G' = greater or equal to
    # sense : 'L' = less or equal to
    # sense : 'E' = equal to
    # ```
    sense::Char
    # ```
    # vc_type = 'C' for core -required for the IP formulation-,
    # vc_type = 'F' for facultative -only helpfull to tighten the LP approximation of the IP formulation-,
    # vc_type = 'S' for constraints defining a subsystem in column generation for
    #            extended formulation approach
    # vc_type = 'M' for constraints defining a pure master constraint
    # vc_type = 'X' for constraints defining a subproblem convexity constraint in the master
    # ```
    vc_type::Char
    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # ```
    flag::Char
    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    status::VCSTATUS
    # ```
    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    member_coef_map::Dict{Variable, Float64}
end


mutable struct Original <: AbstractConstrDuty
    moi_def::MoiConstrDef # explicit Constr
    rep_in_reform::Consrtraint # if any
end


mutable struct PureMasterConstr <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Consrtraint
    data::ANY
end

mutable struct MasterConstr <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Consrtraint
    subprob_var_coef_map::Dict{Variable, Float64}
    mast_col_coef_map::Dict{Variable,Float64} # Variable -> MasterColumn
end


mutable struct Convexity <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
end


mutable struct MasterBranchConstr{T} <: AbstractConstrDuty
    moi_def::MoiVarDef # explicit var
    original_rep::Consrtraint
    branch_var::T
    depth_when_generated::Int
    subprob_var_coef_map::Dict{Variable, Float64}
    mast_col_coef_map::Dict{Variable,Float64} # Variable -> MasterColumn
end



function coluna_print(constr::Constraint{MasterBranchConstr})
    print(constr.branch_var.name, " ")
    if constr.sense == 'G'
        print(">= ")
    elseif constr.sense == 'L'
        print("<= ")
    elseif constr.sense == 'E'
        print("= ")
    end
    println(constr.rhs)
end


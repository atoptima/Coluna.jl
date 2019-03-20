
struct LazySeparationSubproblem <: AbstractFormulation
end

struct UserSeparationSubproblem <: AbstractFormulation
end

struct BlockGenSubproblem <: AbstractFormulation
end

struct BendersSubproblem <: AbstractFormulation
end

struct DantzigWolfeSubproblem <: AbstractFormulation
end

struct Formulation  <: AbstractFormulation
    uid::FormId
    moi_model::MOI.ModelLike
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing} # why nothing ?
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
    coeff_matrix::SparseMatrixCSC{Float64, Int}
    callbacks
    #var_memberships::Dict{VarId, Membership{Variable}}
    #constr_memberships::Dict{ConstrId, Membership{Constraint}}
end

function Formulation(m::AbstractModel, moi::MOI.ModelLike)
    uid = getnewuid(m.form_counter)
    v_man = Manager(Variable)
    c_man = Manager(Constraint)
    matrix = spzeros(MAX_SV_ENTRIES, MAX_SV_ENTRIES)
    #v_md = Dict{VarId, Membership{Variable}}()
    #c_md = Dict{ConstrId, Membership{Constraint}}()
    return ExplicitFormulation(uid, moi, nothing, v_man, c_man, matrix)
end

function register_variable!(f::Formulation, var::Variable, 
        membership::Membership{Variable})
    var_uid = getnewuid(var)
    # store in manager

    println("\e[31m register variable \e[00m")
    return
end

function register_variable!(f::Formulation, var::Variable)
    return register_variable!(f, var, Membership(Variable))
end

function register_constraint!(f::Formulation, constr::Constraint,
        membership::Membership{Constraint})
    constr_uid = getnewuid(constr)

    println("\e[32m register constraint \e[00m")
    return
end


struct Reformulation <: AbstractFormulation
    solution_method::AbstractSolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  MathProgFormulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of  MathProgFormulation or Reformulation
end




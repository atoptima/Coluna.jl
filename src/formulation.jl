
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

struct ExplicitFormulation  <: AbstractMathProgFormulation
    uid::FormId
    moi_model::MOI.ModelLike
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing} # why nothing ?
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
    coeff_matrix::SparseMatrixCSC{Float64, Int}
    #var_memberships::Dict{VarId, Membership{Variable}}
    #constr_memberships::Dict{ConstrId, Membership{Constraint}}
end

function ExplicitFormulation(m::AbstractModel, moi::MOI.ModelLike)
    uid = getnewuid(m.form_counter)
    v_man = Manager(Variable)
    c_man = Manager(Constraint)
    matrix = spzeros(MAX_SV_ENTRIES, MAX_SV_ENTRIES)
    #v_md = Dict{VarId, Membership{Variable}}()
    #c_md = Dict{ConstrId, Membership{Constraint}}()
    return ExplicitFormulation(uid, moi, nothing, v_man, c_man, matrix)
end

function register_variable!(f::ExplicitFormulation, var::Variable, 
        membership::Membership{Variable})
    var_uid = getuid(var)
    # store in manager

    println("\e[31m register variable \e[00m")
    return
end

function register_variable!(f::ExplicitFormulation, var::Variable)
    return register_variable!(f, var, Membership(Variable))
end

function register_constraint!(f::ExplicitFormulation, constr::Constraint,
        membership::Membership{Constraint})
    constr_uid = getuid(constr)

    println("\e[32m register constraint \e[00m")
    return
end

struct ImplicitFormulation <: AbstractMathProgFormulation
    uid::FormId
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
    callback
end

struct Reformulation <: AbstractFormulation
    solution_method::AbstractSolutionMethod
    parent::Union{Nothing, Reformulation} # reference to (pointer to) ancestor
    master::Union{Nothing, ExplicitFormulation} # Nothing ?
    dw_pricing_subprs::Union{Nothing, Vector{DantzigWolfeSubproblem}}
end




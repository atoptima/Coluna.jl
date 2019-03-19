
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
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
end

function ExplicitFormulation(m::AbstractModel, moi::MOI.ModelLike)
    uid = getnewuid(m.form_counter)
    return ExplicitFormulation(uid, moi, nothing, Manager(Variable), Manager(Constraint))
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




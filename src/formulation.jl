
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
    var_manager::Manager
    constr_manager::Manager
end

function ExplicitFormulation(moi::MOI.ModelLike, counter::FormCounter)
    # TODO id
    return ExplicitFormulation(getnewuid(counter), moi, nothing, Manager(), Manager())
end

struct ImplicitFormulation <: AbstractMathProgFormulation
    uid::FormId
    var_manager::Manager
    constr_manager::Manager
    callback
end

struct Reformulation <: AbstractFormulation
    solution_method::AbstractSolutionMethod
    parent::Union{Nothing, Reformulation} # reference to (pointer to) ancestor
    master::Union{Nothing, ExplicitFormulation} # Nothing ?
    dw_pricing_subprs::Union{Nothing, Vector{DantzigWolfeSubproblem}}
end




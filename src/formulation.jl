abstract type AbstractSubproblems end
abstract type AbstractFormulationNature end

struct Formulation{FormNature <: AbstractFormulationNature, SubProbsType <: AbstractSubproblems}
    parent::Union{Nothing, Formulation}
    master::FormNature
    subproblems::SubProbsType
    var_manager::Manager # store variables of this formulation only
    constr_manager::Manager # store constraints of this formulation only
end

function OriginalFormulation(moi_model::MOI.ModelLike)
    return Formulation(nothing, ExplicitFormulation(moi_model),
        NoSubproblem(), Manager{Variable}(), Manager{Constraint}())
end

struct ExplicitFormulation <: AbstractFormulationNature
    moi_model::MOI.ModelLike
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
end

function ExplicitFormulation(moi::MOI.ModelLike)
    
end

struct ImplicitFormulation <: AbstractFormulationNature
    callback
end

struct NoSubproblem <: AbstractSubproblems end

struct LazySeparationSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct UserSeparationSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct BlockGenSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct BendersSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct DantzigWolfeSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct HybdridSubproblems <: AbstractSubproblems
    subproblems::Vector{AbstractSubproblems}
end

struct ExplicitFormulation <: AbstractFormulationNature
    moi_model::MOI.ModelLike
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
end

function ExplicitFormulation(moi::MOI.ModelLike)
    return ExplicitFormulation(moi, Manager{Variable}(), Manager{Constraint}())
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

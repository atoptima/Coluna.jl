struct Formulation{FormNature <: AbstractFormulationNature, SubProbsType <: AbstractSubproblems}
    parent::Union{Nothing, Formulation}
    master::FormNature
    subproblems::SubProbsType
end

function OriginalFormulation(moi_model::MOI.ModelLike)
    return Formulation(nothing, ExplicitFormulation(moi_model), NoSubproblem())
end
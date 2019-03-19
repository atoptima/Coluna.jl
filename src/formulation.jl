struct ReFormulation <:  AbstractFormulation
    solution_method
    parent::Union{Nothing, Formulation} # reference to (pointer to) ancestor
    master::Union{Nothing, ExplicitFormulation}
    dw_pricing_subprs::Union{Nothing, Vector{DantzigWolfeSubproblem}}
end

function OriginalFormulation(moi_model::MOI.ModelLike)
    return Formulation(nothing, ExplicitFormulation(moi_model), nothing)
end

struct ExplicitFormulation  <: AbstractMathProgFormulation
    uid::Id{AbstractMathProgFormulation}
    moi_model::MOI.ModelLike
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
end

function ExplicitFormulation(moi::MOI.ModelLike)
    # TODO id
    return ExplicitFormulation(0, moi, Manager{Variable}(), Manager{Constraint}())
end

struct ImplicitFormulation <: AbstractMathProgFormulation
    uid::Id{AbstractMathProgFormulation}
    var_manager::Manager{Variable}
    constr_manager::Manager{Constraint}
    callback
end

struct Reformulation <: AbstractFormulation
    #solution_method
    parent::Union{Nothing, Reformulation} # reference to (pointer to) ancestor
    master::Union{Nothing, ExplicitFormulation} # Nothing ?
    dw_pricing_subprs::Vector{AbstractMathProgFormulation}
end

function OriginalFormulation(moi_model::MOI.ModelLike)
     return ExplicitFormulation(moi_model)
end

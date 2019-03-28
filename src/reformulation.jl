mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    timer_output::TimerOutputs.TimerOutput
end


function Reformulation(model::AbstractModel, method::SolutionMethod)
    return Reformulation(method, nothing, nothing, Vector{AbstractFormulation}(), Inf, -Inf, model.timer_output)
end

function Reformulation(model::AbstractModel)
    return Reformulation(model, DirectMip)
end

getmaster(r::Reformulation) = r.master

setmaster!(r::Reformulation, f) = r.master = f
add_dw_pricing_sp!(r::Reformulation, f) = push!(r.dw_pricing_subprs, f)
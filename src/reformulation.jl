mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    timer_output::TimerOutputs.TimerOutput
end

function set_prob_ref_to_problem_dict(extended_problem::Reformulation)
    prob_ref_to_prob = extended_problem.problem_ref_to_problem
    master = extended_problem.master
    subproblems = extended_problem.dw_pricing_subprs
    prob_ref_to_prob[master.uid] = master
    for subprob in subproblems
        prob_ref_to_prob[subprob.uid] = subprob
    end
    return
end

function Reformulation(model::AbstractModel, method::SolutionMethod)
    return Reformulation(method, nothing, nothing, Vector{AbstractFormulation}(), Inf, -Inf, model.timer_output)
end

function Reformulation(model::AbstractModel)
    return Reformulation(model, DirectMip)
end

function setmaster!(r::Reformulation, f)
    r.master = f
    return
end

function add_dw_pricing_sp!(r::Reformulation, f)
    push!(r.dw_pricing_subprs, f)
    return
end
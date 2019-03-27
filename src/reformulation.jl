mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    prob_ref_to_prob::Dict{Int, AbstractFormulation}
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
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
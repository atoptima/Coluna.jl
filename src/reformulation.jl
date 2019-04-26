"""
    Reformulation

Representation of a formulation which is solved by Coluna using a decomposition approach. All the sub-structures are defined within the struct `Reformulation`.
"""
mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
    dw_pricing_sp_lb::Dict{FormId, Id} # Attribute has ambiguous name
    dw_pricing_sp_ub::Dict{FormId, Id}
    timer_output::TimerOutputs.TimerOutput
    # strategy::AbstractStrategy
end

"""
    Reformulation(prob::AbstractProblem)

Constructs a `Reformulation`.
"""
Reformulation(prob::AbstractProblem) = Reformulation(prob, DirectMip)

"""
    Reformulation(prob::AbstractProblem, method::SolutionMethod)

Constructs a `Reformulation` that shall be solved using the `SolutionMethod` `method`.
"""
function Reformulation(prob::AbstractProblem, method::SolutionMethod)
    return Reformulation(method,
                         nothing,
                         nothing,
                         Vector{AbstractFormulation}(),
                         Dict{FormId, Int}(),
                         Dict{FormId, Int}(),
                         prob.timer_output)
end

getmaster(r::Reformulation) = r.master
setmaster!(r::Reformulation, f) = r.master = f
add_dw_pricing_sp!(r::Reformulation, f) = push!(r.dw_pricing_subprs, f)

function initialize_moi_optimizer(reformulation::Reformulation,
                                  master_factory::JuMP.OptimizerFactory,
                                  pricing_factory::JuMP.OptimizerFactory)
    initialize_moi_optimizer(reformulation.master, master_factory)
    for problem in reformulation.dw_pricing_subprs
        initialize_moi_optimizer(problem, pricing_factory)
    end
end

function optimize!(reformulation::Reformulation)
    res = apply(TreeSolver, reformulation)
    return res
end

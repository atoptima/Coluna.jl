"""
    Reformulation

Representation of a formulation which is solved by Coluna using a decomposition approach. All the sub-structures are defined within the struct `Reformulation`.
"""
mutable struct Reformulation <: AbstractFormulation
    strategy::GlobalStrategy
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
    dw_pricing_sp_lb::Dict{FormId, Id} # Attribute has ambiguous name
    dw_pricing_sp_ub::Dict{FormId, Id}
end

"""
    Reformulation(prob::AbstractProblem)

Constructs a `Reformulation`.
"""
Reformulation(prob::AbstractProblem) = Reformulation(prob, GlobalStrategy())

"""
    Reformulation(prob::AbstractProblem, method::SolutionMethod)

Constructs a `Reformulation` that shall be solved using the `GlobalStrategy` `strategy`.
"""
function Reformulation(prob::AbstractProblem, strategy::GlobalStrategy)
    return Reformulation(strategy,
                         nothing,
                         nothing,
                         Vector{AbstractFormulation}(),
                         Dict{FormId, Int}(),
                         Dict{FormId, Int}())
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
    res = apply!(GlobalStrategy, reformulation)
    return res
end

# Following two functions are temporary, we must store a pointer to the vc
# being represented by a representative vc
function vc_belongs_to_formulation(f::Formulation, vc::AbstractVarConstr)
    !haskey(f, getid(vc)) && return false
    vc_in_formulation = getelem(f, getid(vc))
    get_cur_is_explicit(vc_in_formulation) && return true
    return false
end

function find_owner_formulation(f::Reformulation, vc::AbstractVarConstr)
    vc_belongs_to_formulation(f.master, vc) && return f.master
    for p in f.dw_pricing_subprs
        vc_belongs_to_formulation(p, vc) && return p
    end
   @error(string("VC ", getname(vc), " does not belong to any problem in reformulation"))
end

function deactivate!(reform::Reformulation, id::Id)
    haskey(reform.master, id) && deactivate!(reform.master, id)
    for p in reform.dw_pricing_subprs
        haskey(p, id) && deactivate!(p, id)
    end
end

function activate!(reform::Reformulation, id::Id)
    haskey(reform.master, id) && activate!(reform.master, id)
    for p in reform.dw_pricing_subprs
        haskey(p, id) && activate!(p, id)
    end
end

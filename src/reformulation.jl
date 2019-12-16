"""
    Reformulation

Representation of a formulation which is solved by Coluna using a decomposition approach. All the sub-structures are defined within the struct `Reformulation`.
"""
mutable struct Reformulation <: AbstractFormulation
    strategy::GlobalStrategy
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Dict{FormUid, AbstractFormulation} # vector of Formulation or Reformulation
    benders_sep_subprs::Dict{FormUid, AbstractFormulation}
    dw_pricing_sp_lb::Dict{FormUid, Id} # Attribute has ambiguous name
    dw_pricing_sp_ub::Dict{FormUid, Id}
end

"""
    Reformulation(prob::AbstractProblem, method::SolutionMethod)

Constructs a `Reformulation` that shall be solved using the `GlobalStrategy` `strategy`.
 """
function Reformulation(prob::AbstractProblem, strategy::GlobalStrategy)
    return Reformulation(strategy,
                         nothing,
                         nothing,
                         Dict{FormUid, AbstractFormulation}(),
                         Dict{FormUid, AbstractFormulation}(),
                         Dict{FormUid, Int}(),
                         Dict{FormUid, Int}())
end

getglobalstrategy(r::Reformulation) = r.strategy
setglobalstrategy!(r::Reformulation, strategy::GlobalStrategy) = r.strategy = strategy
getmaster(r::Reformulation) = r.master
setmaster!(r::Reformulation, f) = r.master = f
add_dw_pricing_sp!(r::Reformulation, f) = r.dw_pricing_subprs[getuid(f)] = f
add_benders_sep_sp!(r::Reformulation, f) = r.benders_sep_subprs[getuid(f)] = f
get_dw_pricing_sps(r::Reformulation) = r.dw_pricing_subprs
get_benders_sep_sps(r::Reformulation) = r.benders_sep_subprs

function optimize!(
        reform::Reformulation; strategy::GlobalStrategy = reform.strategy
    )
    prepare!(strategy, reform)
    opt_result = run_reform_solver!(reform, strategy) 
    master = getmaster(reform)
    for (idx, sol) in enumerate(getprimalsols(opt_result))
        opt_result.primal_sols[idx] = proj_cols_on_rep(sol, master)
    end
    return opt_result
end

# Following two functions are temporary, we must store a pointer to the vc
# being represented by a representative vc
function vc_belongs_to_formulation(f::Formulation, vc::AbstractVarConstr)
    !haskey(f, getid(vc)) && return false
    vc_in_formulation = getelem(f, getid(vc))
    get_cur_is_explicit(vc_in_formulation) && return true
    return false
end

function find_owner_formulation(reform::Reformulation, vc::AbstractVarConstr)
    vc_belongs_to_formulation(reform.master, vc) && return reform.master
    for spform in get_dw_pricing_sps(reform)
        vc_belongs_to_formulation(spform, vc) && return spform
    end
   @error(string("VC ", getname(vc), " does not belong to any problem in reformulation"))
end

function deactivate!(reform::Reformulation, id::Id)
    haskey(reform.master, id) && deactivate!(reform.master, id)
    for spform in get_dw_pricing_sps(reform)
         haskey(spform, id) && deactivate!(spform, id)
    end
end

function activate!(reform::Reformulation, id::Id)
    haskey(reform.master, id) && activate!(reform.master, id)
    for spform in get_dw_pricing_sps(reform)
        haskey(spform, id) && activate!(spform, id)
    end
end

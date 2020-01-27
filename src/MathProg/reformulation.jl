mutable struct Reformulation <: AbstractFormulation
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Dict{FormId, AbstractFormulation} # vector of Formulation or Reformulation
    benders_sep_subprs::Dict{FormId, AbstractFormulation}
    dw_pricing_sp_lb::Dict{FormId, Id} # Attribute has ambiguous name
    dw_pricing_sp_ub::Dict{FormId, Id}
end

"""
`Reformulation` is a representation of a formulation which is solved by Coluna 
using a decomposition approach.

    Reformulation(prob::AbstractProblem)

Construct a `Reformulation` for problem `prob`.
 """
function Reformulation(prob::AbstractProblem)
    return Reformulation(nothing,
                         nothing,
                         Dict{FormId, AbstractFormulation}(),
                         Dict{FormId, AbstractFormulation}(),
                         Dict{FormId, Int}(),
                         Dict{FormId, Int}())
end

getmaster(r::Reformulation) = r.master
setmaster!(r::Reformulation, f) = r.master = f
add_dw_pricing_sp!(r::Reformulation, f) = r.dw_pricing_subprs[getuid(f)] = f
add_benders_sep_sp!(r::Reformulation, f) = r.benders_sep_subprs[getuid(f)] = f
get_dw_pricing_sps(r::Reformulation) = r.dw_pricing_subprs
get_benders_sep_sps(r::Reformulation) = r.benders_sep_subprs

# Following two functions are temporary, we must store a pointer to the vc
# being represented by a representative vc
function vc_belongs_to_formulation(form::Formulation, vc::AbstractVarConstr)
    !haskey(form, getid(vc)) && return false
    vc_in_formulation = getelem(form, getid(vc))
    getcurisexplicit(form, vc_in_formulation) && return true
    return false
end

function find_owner_formulation(reform::Reformulation, vc::AbstractVarConstr)
    vc_belongs_to_formulation(reform.master, vc) && return reform.master
    for (formid, spform) in get_dw_pricing_sps(reform)
        vc_belongs_to_formulation(spform, vc) && return spform
    end
   @error(string("VC ", vc.name, " does not belong to any problem in reformulation"))
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

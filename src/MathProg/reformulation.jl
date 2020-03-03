mutable struct Reformulation <: AbstractFormulation
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Dict{FormId, AbstractModel} 
    benders_sep_subprs::Dict{FormId, AbstractModel}
    dw_pricing_sp_lb::Dict{FormId, Id} # Attribute has ambiguous name
    dw_pricing_sp_ub::Dict{FormId, Id}
    storages::Dict{Type{<:AbstractStorage}, AbstractStorage}
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
                         Dict{FormId, AbstractModel}(),
                         Dict{FormId, AbstractModel}(),
                         Dict{FormId, Int}(),
                         Dict{FormId, Int}(),
                         Dict{Type{<:AbstractStorage}, AbstractStorage}())
end

getstoragedict(form::Reformulation)::StorageDict = form.storages

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
    iscurexplicit(form, vc_in_formulation) && return true
    return false
end

function find_owner_formulation(reform::Reformulation, vc::AbstractVarConstr)
    vc_belongs_to_formulation(reform.master, vc) && return reform.master
    for (formid, spform) in get_dw_pricing_sps(reform)
        vc_belongs_to_formulation(spform, vc) && return spform
    end
   @error(string("VC ", vc.name, " does not belong to any problem in reformulation"))
end

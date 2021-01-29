# TODO make immutable
mutable struct Reformulation <: AbstractFormulation
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation (TODO rm Nothing)
    master::Union{Nothing, Formulation}  # TODO : rm Nothing
    dw_pricing_subprs::Dict{FormId, AbstractModel} 
    benders_sep_subprs::Dict{FormId, AbstractModel}
    dw_pricing_sp_lb::Dict{FormId, ConstrId}
    dw_pricing_sp_ub::Dict{FormId, ConstrId}
end

"""
`Reformulation` is a representation of a formulation which is solved by Coluna 
using a decomposition approach.

    Reformulation()

Construct an empty `Reformulation`.
 """
Reformulation() = Reformulation(
    nothing,
    nothing,
    Dict{FormId, AbstractModel}(),
    Dict{FormId, AbstractModel}(),
    Dict{FormId, ConstrId}(),
    Dict{FormId, ConstrId}()
)

"""
    getobjsense(reformulation)

Return the objective sense of the master problem of the reformulation.
If the master problem has not been defined, it throws an error.
"""
function getobjsense(r::Reformulation)
    r.master !== nothing && return getobjsense(r.master)
    error("Undefined master in the reformulation, cannot return the objective sense.")
end

"""
    getmaster(reformulation)

Return the formulation of the master problem.
"""
getmaster(r::Reformulation) = r.master

# TODO : remove
setmaster!(r::Reformulation, f::Formulation) = r.master = f

"""
    add_dw_pricing_sp!(reformulation, abstractmodel)

Add a Dantzig-Wolfe pricing subproblem in the reformulation.
"""
add_dw_pricing_sp!(r::Reformulation, f) = r.dw_pricing_subprs[getuid(f)] = f

"""
    add_benders_sep_sp!(reformulation, abstractmodel)

Add a Benders separation subproblem in the reformulation.
"""
add_benders_sep_sp!(r::Reformulation, f) = r.benders_sep_subprs[getuid(f)] = f

"""
    get_dw_pricing_sps(reformulation)

Return a `Dict{FormId, AbstractModel}` containing all Dabtzig-Wolfe pricing subproblems of
the reformulation.
"""
get_dw_pricing_sps(r::Reformulation) = r.dw_pricing_subprs

"""
    get_benders_sep_sps(reformulation)

Return a `Dict{FormId, AbstractModel}` containing all Benders separation subproblems of the
reformulation.
"""
get_benders_sep_sps(r::Reformulation) = r.benders_sep_subprs

"""
    get_dw_pricing_sp_ub_constrid(reformulation, spid::FormId)

Return the `ConstrId` of the upper bounded convexity constraint of Dantzig-Wolfe pricing
subproblem with id `spid`.
"""
get_dw_pricing_sp_ub_constrid(r::Reformulation, spid::FormId) = r.dw_pricing_sp_ub[spid]

"""
    get_dw_pricing_sp_lb_constrid(reformulation, spid::FormId)

Return the `ConstrId` of the lower bounded convexity constraint of Dantzig-Wolfe pricing
subproblem with id `spid`.
"""
get_dw_pricing_sp_lb_constrid(r::Reformulation, spid::FormId) = r.dw_pricing_sp_lb[spid]

# Following two functions are temporary, we must store a pointer to the vc
# being represented by a representative vc
function vc_belongs_to_formulation(form::Formulation, vc::AbstractVarConstr)
    !haskey(form, getid(vc)) && return false
    vc_in_formulation = getelem(form, getid(vc))
    isexplicit(form, vc_in_formulation) && return true
    return false
end

function find_owner_formulation(reform::Reformulation, vc::AbstractVarConstr)
    vc_belongs_to_formulation(reform.master, vc) && return reform.master
    for (formid, spform) in get_dw_pricing_sps(reform)
        vc_belongs_to_formulation(spform, vc) && return spform
    end
   @error(string("VC ", vc.name, " does not belong to any problem in reformulation"))
end

function Base.show(io::IO, reform::Reformulation)
    compact = get(io, :compact, false)
    if compact
        print(io, "Reformulation")
    end
end

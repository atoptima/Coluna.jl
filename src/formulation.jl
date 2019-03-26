# struct LazySeparationSubproblem <: AbstractFormulation
# end

# struct UserSeparationSubproblem <: AbstractFormulation
# end

# struct BlockGenSubproblem <: AbstractFormulation
# end

# struct BendersSubproblem <: AbstractFormulation
# end

# struct DantzigWolfeSubproblem <: AbstractFormulation
# end

mutable struct Formulation  <: AbstractFormulation
    uid::FormId
    moi_model::Union{MOI.ModelLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    vars::Dict{VarId, Variable} 
    constrs::Dict{ConstrId, Constraint}
    memberships::Memberships
    var_status::Filter
    constr_status::Filter
    var_duty_sets::Dict{VarDuty, Vector{VarId}}
    constr_duty_sets::Dict{ConstrDuty, Vector{ConstrId}}
    callbacks
    obj_sense::ObjSense
end

function setvarduty!(f::Formulation, var::Variable)
    var_uid = getuid(var)
    var_duty = getduty(var)
    if haskey(f.var_duty_sets, var_duty)   
        var_duty_set = f.var_duty_sets[var_duty]
    else
        var_duty_set = f.var_duty_sets[var_duty] = Vector{VarId}()
    end
    push!(var_duty_set, var_uid)
    return
end

function setconstrduty!(f::Formulation, constr::Constraint)
    constr_uid = getuid(constr)
    constr_duty = getduty(constr)
    if haskey(f.constr_duty_sets, constr_duty)   
        constr_duty_set = f.constr_duty_sets[constr_duty]
    else
        constr_duty_set = f.constr_duty_sets[constr_duty] = Vector{ConstrId}()
    end
    push!(constr_duty_set, constr_uid)
    return
end

#getvarcost(f::Formulation, uid) = f.costs[uid]
#getvarlb(f::Formulation, uid) = f.lower_bounds[uid]
#getvarub(f::Formulation, uid) = f.upper_bounds[uid]
#getvartype(f::Formulation, uid) = f.var_types[uid]

#getconstrrhs(f::Formulation, uid) = f.rhs[uid]
#getconstrsense(f::Formulation, uid) = f.constr_senses[uid]

activevar(f::Formulation) = activemask(f.var_status)
staticvar(f::Formulation) = staticmask(f.var_status)
artificalvar(f::Formulation) = artificialmask(f.var_status)
activeconstr(f::Formulation) = activemask(f.constr_status)
staticconstr(f::Formulation) = staticmask(f.constr_status)x

function getvar_uids(f::Formulation,d::VarDuty)
    if haskey(f.var_duty_sets, d)
        return f.var_duty_sets[d]
    end
    return Vector{VarId}()
end

function getconstr_uids(f::Formulation,d::VarDuty)
    if haskey(f.constr_duty_sets,d)
        return f.constr_duty_sets[d]
    end
    return Vector{ConstrId}()
end

#getvar(f::Formulation, uid::VarId) = f.var_duty_sets[d]

getuid(f::Formulation) = f.uid
getvar(f::Formulation, uid) = f.vars[uid]
getconstr(f::Formulation, uid) = f.constrs[uid]
        
get_constr_members_of_var(f::Formulation, uid) = get_constr_members_of_var(f.memberships, uid)
get_var_members_of_constr(f::Formulation, uid) = get_var_members_of_constr(f.memberships, uid)

get_constr_members(f::Formulation, var::Variable) = getvarmembership(f, getuid(var))
getmembership(f::Formulation, constr::Constraint) = getconstrmembership(f, getuid(constr))

function Formulation(m::AbstractModel)
    return Formulation(m::AbstractModel, nothing)
end

function Formulation(m::AbstractModel, moi::Union{MOI.ModelLike, Nothing})
    uid = getnewuid(m.form_counter)
    # costs = spzeros(Float64, MAX_SV_ENTRIES)
    # lb = spzeros(Float64, MAX_SV_ENTRIES)
    # ub = spzeros(Float64, MAX_SV_ENTRIES)
    # rhs = spzeros(Float64, MAX_SV_ENTRIES)
    # vtypes = Dict{VarId, VarKind}()
    # csenses = Dict{ConstrId, ConstrSense}()
    return Formulation(uid, moi, nothing, 
                       Dict{VarId, Variable}(), Dict{ConstrId, Constraint}(),
                       Memberships(), Filter(), Filter(),
                       Dict{VarDuty, Vector{VarId}}(), 
                       Dict{ConstrDuty, Vector{ConstrId}}(),
                       nothing, Min)
end


function copy_in_formulation!(varconstr::AbstractVarConstr, src::Formulation, dest::Formulation, duty)
    varconstr_copy = deepcopy(varconstr)
    setform!(varconstr_copy, getuid(dest))
    setduty!(varconstr_copy, duty)
    add!(dest, varconstr_copy)
    return varconstr_copy
end

#==function copy_in_formulation!(varconstr::AbstractVarConstr, src::Formulation, dest::Formulation, duty; membership = false)
    varconstr_copy = deepcopy(varconstr)
    setform!(varconstr_copy, getuid(dest))
    setduty!(varconstr_copy, duty)
    if membership
        m = get_constr_members(src, varconstr)
        m_copy = deepcopy(m)
        add!(dest, varconstr_copy, m_copy)
    else
        add!(dest, varconstr_copy)
    end
    return
end ==#


function add!(f::Formulation, elems::Vector{T}) where {T <: AbstractVarConstr}
    for elem in elems
        add!(f, elem)
    end
    return
end

function add!(f::Formulation, elems::Vector{T}, 
        memberships::Vector{SparseVector}) where {T <: AbstractVarConstr}
    @assert length(elems) == length(memberships)
    for i in 1:length(elems)
        add!(f, elems[i], memberships[i])
    end
    return
end

function add!(f::Formulation, var::Variable)
    var_uid = getuid(var)
    setvarduty!(f, var)
    f.vars[var_uid] = var
    add_variable!(f.memberships, var_uid)
    # TODO : Register in filter
    return
end

function add!(f::Formulation, constr::Constraint)
    constr_uid = getuid(constr)
    setconstrduty!(f, constr)
    f.constrs[constr_uid] = constr
    add_constraint!(f.memberships, constr_uid)
    # TODO : Register in filter
    return
end

function add!(f::Formulation, constr::Constraint, membership::SparseVector)
    constr_uid = getuid(constr)
    setconstrduty!(f, constr)
    f.constrs[constr_uid] = constr
    add_constraint!(f.memberships, constr_uid, membership)
    # TODO : Register in filter
    return
end

function register_objective_sense!(f::Formulation, min::Bool)
    # if !min
    #     m.obj_sense = Max
    #     m.costs *= -1.0
    # end
    !min && error("Coluna does not support maximization yet.")
    return
end

mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
end

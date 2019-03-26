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
    parent_formulation::Union{Formulation, Nothing}
    moi_model::Union{MOI.ModelLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    vars::SparseVector{Variable,VarId} 
    constrs::SparseVector{Constraint,ConstrId} 
    #constrs::Dict{ConstrId, Constraint}
    memberships::Memberships
    var_status::Filter
    constr_status::Filter
    var_duty_sets::Dict{VarDuty, Vector{VarId}}
    constr_duty_sets::Dict{ConstrDuty, Vector{ConstrId}}
    obj_sense::ObjSense
    map_var_uid_to_index::Dict{VarId, MoiVarIndex}
    map_constr_uid_to_index::Dict{ConstrId, MoiConstrIndex}
    map_index_to_var_uid::Dict{MoiVarIndex, VarId}
    map_index_to_constr_uid::Dict{MoiConstrIndex, ConstrId}
    var_bounds::Dict{VarId, MoiVarBound}
    var_kinds::Dict{VarId, MoiVarKind}
    callbacks
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

activevar(f::Formulation) = f.vars[activemask(f.var_status)]
staticvar(f::Formulation) = f.vars[staticmask(f.var_status)]
dynamicvar(f::Formulation) = f.vars[dynamicmask(f.var_status)]
artificalvar(f::Formulation) = f.vars[artificialmask(f.var_status)]
activeconstr(f::Formulation) = f.constrs[activemask(f.constr_status)]
staticconstr(f::Formulation) = f.constrs[staticmask(f.constr_status)]
dynamicconstr(f::Formulation) = f.constrs[dynamicmask(f.constr_status)]

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

get_constr_members_of_var(f::Formulation, var::Variable) = get_constr_members_of_var(f, getuid(var))
get_var_members_of_constr(f::Formulation, constr::Constraint) = get_var_members_of_constr(f, getuid(constr))



function Formulation(m::AbstractModel,
                     parent_formulation::Union{Formulation, Nothing},
                     moi_model::Union{MOI.ModelLike, Nothing})
    uid = getnewuid(m.form_counter)
    
    return Formulation(uid,
                       parent_formulation,
                       moi_model,
                       nothing, 
                       spzeros(MAX_SV_ENTRIES), #SparseVector{Variable,VarId}(),
                       spzeros(MAX_SV_ENTRIES), #SparseVector{Constraint,ConstrId}(),
                       Memberships(),
                       Filter(),
                       Filter(),
                       Dict{VarDuty, Vector{VarId}}(), 
                       Dict{ConstrDuty, Vector{ConstrId}}(),
                       Min,
                       Dict{VarId, MoiVarIndex}(),
                       Dict{ConstrId, MoiConstrIndex}(),
                       Dict{MoiVarIndex, VarId}(),
                       Dict{MoiConstrIndex, ConstrId}(),
                       Dict{VarId, MoiVarBound}(),
                       Dict{VarId, MoiVarKind}(),
                       nothing)
end
function Formulation(m::AbstractModel, moi::Union{MOI.ModelLike, Nothing})
    return Formulation(m::AbstractModel,  nothing, moi)
end
function Formulation(m::AbstractModel, parent_formulation::Union{Formulation, Nothing})
    return Formulation(m::AbstractModel, parent_formulation, nothing)
end
function Formulation(m::AbstractModel)
    return Formulation(m::AbstractModel, nothing, nothing)
end


function clone_in_formulation!(varconstr::AbstractVarConstr, src::Formulation, dest::Formulation, duty)
    varconstr_copy = deepcopy(varconstr)
    setform!(varconstr_copy, getuid(dest))
    setduty!(varconstr_copy, duty)
    add!(dest, varconstr_copy)
    return varconstr_copy
end

function clone_in_formulation!(var_uids::Vector{VarId},
                               src_form::Formulation,
                               dest_form::Formulation,
                               duty::VarDuty)
    for var_uid in var_uids
        var = getvar(src_form, var_uid)
        var_clone = clone_in_formulation!(var, src_form, dest_form, duty)
        reset_constr_members_of_var!(dest_form.memberships, var_uid,
                                     get_constr_members_of_var(src_form, var_uid))
    end
    
    return 
end

function clone_in_formulation!(constr_uids::Vector{ConstrId},
                               src_form::Formulation,
                               dest_form::Formulation,
                               duty::ConstrDuty)
    for constr_uid in constr_uids
        constr = getconstr(src_form, constr_uid)
        constr_clone = clone_in_formulation!(constr, src_form, dest_form, duty)
        set_var_members_of_constr!(dest_form.memberships, constr_uid,
                                     get_var_members_of_constr(src_form, constr_uid))
    end
    
    return 
end

#==function clone_in_formulation!(varconstr::AbstractVarConstr, src::Formulation, dest::Formulation, duty; membership = false)
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


function record!(f::Formulation, var::Variable)
    var_uid = getuid(var)
    setvarduty!(f, var)
    f.vars[var_uid] = var
    f.var_status.used_mask[var_uid] = true
    f.var_status.active_mask[var_uid] = true
    if (var.flag == Static)
        f.var_status.static_mask[var_uid] = true
    elseif (var.flag == Artificial)
        f.var_status.artificial_mask[var_uid] = true
    elseif (var.flag == Implicit)
        f.var_status.implicit_mask[var_uid] = true
    end
    return
end

function add!(f::Formulation, var::Variable)
    record!(f,var)
    add_variable!(f.memberships, getuid(var))
    return
end

function record!(f::Formulation, constr::Constraint)
    constr_uid = getuid(constr)
    setconstrduty!(f, constr)
    f.constrs[constr_uid] = constr
    f.constr_status.used_mask[constr_uid] = true
    f.constr_status.active_mask[constr_uid] = true
    if (constr.flag == Static)
        f.constr_status.static_mask[constr_uid] = true
    elseif (constr.flag == Implicit)
        f.constr_status.implicit_mask[constr_uid] = true
    end
   return
end

function add!(f::Formulation, constr::Constraint)
    record!(f,constr)
    add_constraint!(f.memberships, getuid(constr))
    return
end

function add!(f::Formulation, constr::Constraint, membership::SparseVector)
    record!(f,constr)
    add_constraint!(f.memberships, getuid(constr), membership)
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



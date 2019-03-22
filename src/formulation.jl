struct LazySeparationSubproblem <: AbstractFormulation
end

struct UserSeparationSubproblem <: AbstractFormulation
end

struct BlockGenSubproblem <: AbstractFormulation
end

struct BendersSubproblem <: AbstractFormulation
end

struct DantzigWolfeSubproblem <: AbstractFormulation
end

struct Memberships
    var_memberships::Dict{VarId, SparseVector{Float64, ConstrId}}
    constr_memberships::Dict{ConstrId, SparseVector{Float64, VarId}}
end

hasvar(m::Memberships, uid) = haskey(m.var_memberships, uid)
hasconstr(m::Memberships, uid) = haskey(m.constr_memberships, uid)

function getvarmembership(m::Memberships, uid) 
    hasvar(m, uid) && return m.var_memberships[uid]
    error("Variable $uid not stored in formulation.")
end

function getconstrmembership(m::Memberships, uid) 
    hasconstr(m, uid) && return m.constr_memberships[uid]
    error("Constraint $uid not stored in formulation.")
end

function Memberships()
    var_m = Dict{VarId, SparseVector{Float64, ConstrId}}()
    constr_m = Dict{ConstrId, SparseVector{Float64, VarId}}()
    return Memberships(var_m, constr_m)
end

function add_variable!(m::Memberships,  var_uid::VarId)
    m.var_memberships[var_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_constraint!(m::Memberships,
                         constr_uid::ConstrId, 
                         membership::SparseVector) 
    m.constr_memberships[constr_uid] = membership
    var_uids, vals = findnz(membership)
    for j in 1:length(var_uids)
        !hasvar(m, var_uids[j]) && error("Variable $(var_uids[j]) not registered in Memberships.")
        m.var_memberships[var_uids[j]][constr_uid] = vals[j]
    end
    return
end

mutable struct Formulation  <: AbstractFormulation
    uid::FormId
    moi_model::Union{MOI.ModelLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing} # why nothing ?
    #var_manager::Manager{Variable}
    #constr_manager::Manager{Constraint}
    # Min \{ cx | Ax <= b, Ex = f, l <= x <= u \}
    memberships::Memberships
    costs::SparseVector{Float64, Int}
    lower_bounds::SparseVector{Float64, Int}
    upper_bounds::SparseVector{Float64, Int}
    rhs::SparseVector{Float64, Int}
    callbacks
    # Data used for displaying (not computing) :
    var_types::Dict{VarId, VarType}
    constr_senses::Dict{ConstrId, ConstrSense}
    obj_sense::ObjSense
end

getvarcost(f::Formulation, uid) = f.costs[uid]
getvarlb(f::Formulation, uid) = f.lower_bounds[uid]
getvarub(f::Formulation, uid) = f.upper_bounds[uid]
getvartype(f::Formulation, uid) = f.var_types[uid]

getconstrrhs(f::Formulation, uid) = f.rhs[uid]
getconstrsense(f::Formulation, uid) = f.constr_senses[uid]

getvarmembership(f::Formulation, uid) = getvarmembership(f.memberships, uid)
getconstrmembership(f::Formulation, uid) = getconstrmembership(f.memberships, uid)

mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of Formulation or Reformulation
end

function Formulation(m::AbstractModel)
    return Formulation(m::AbstractModel, nothing)
end

function Formulation(m::AbstractModel, moi::Union{MOI.ModelLike, Nothing})
    uid = getnewuid(m.form_counter)
    #v_man = Manager(Variable)
    #c_man = Manager(Constraint)
    costs = spzeros(Float64, MAX_SV_ENTRIES)
    lb = spzeros(Float64, MAX_SV_ENTRIES)
    ub = spzeros(Float64, MAX_SV_ENTRIES)
    rhs = spzeros(Float64, MAX_SV_ENTRIES)
    vtypes = Dict{VarId, VarType}()
    csenses = Dict{ConstrId, ConstrSense}()
    return Formulation(uid, moi, nothing, Memberships(), costs, lb, ub, rhs, 
        nothing, vtypes, csenses, Min)
end

function register_variable!(f::Formulation, 
                            var_uid::VarId, 
                            cost::Float64,
                            lb::Float64, 
                            ub::Float64, 
                            vtype::VarType)
    add_variable!(f.memberships, var_uid)
    f.costs[var_uid] = cost
    f.lower_bounds[var_uid] = lb
    f.upper_bounds[var_uid] = ub
    f.var_types[var_uid] = vtype
    # TODO : Register in manager
    return
end

function register_variable!(f::Formulation, 
                            var::Variable, 
                            cost::Float64,
                            lb::Float64, 
                            ub::Float64, 
                            vtype::VarType)
    uid = getuid(var)
    register_variable!(f, uid, cost, lb, ub, vtype)
    return
end

function register_variables!(f::Formulation,
                             vars::Vector{Variable}, 
                             costs::Vector{Float64},
                             lb::Vector{Float64},
                             ub::Vector{Float64}, 
                             vtypes::Vector{VarType})
    @assert length(vars) == length(costs) == length(ub)
    @assert length(vars) == length(lb) == length(vtypes)
    for i in 1:length(vars)
        register_variable!(f, vars[i], costs[i], lb[i], ub[i], vtypes[i])
    end
    return
end

function register_constraint!(f::Formulation,
                              constr_uid::ConstrId,
                              csense::ConstrSense,
                              rhs::Float64,
                              membership::SparseVector)
    f.rhs[constr_uid] = rhs
    f.constr_senses[constr_uid] = csense
    # TODO : register in manager
    add_constraint!(f.memberships, constr_uid, membership)
    return
end

function register_constraint!(f::Formulation, 
                              constr::Constraint, 
                              csense::ConstrSense, 
                              rhs::Float64,
                              membership::SparseVector)
    uid = getuid(constr)
    register_constraint!(f, uid, csense, rhs, membership)
    return
end

function register_constraints!(f::Formulation,
                               constrs::Vector{Constraint},
                               csenses::Vector{ConstrSense},
                               rhs::Vector{Float64},
                               memberships::Vector{SparseVector})
    @assert length(constrs) == length(memberships) == length(csenses) == length(rhs)
    # register in manager
    for i in 1:length(constrs)
        register_constraint!(f, constrs[i], csenses[i], rhs[i], memberships[i])
    end
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

function copy_variables!(dest::Formulation, src::Formulation, uids;
        copy_membership = false)
    for uid in uids
        if copy_membership
            error("TODO")
        else
            register_variable!(dest, uid, getvarcost(src, uid), 
                getvarlb(src, uid), getvarub(src, uid), getvartype(src, uid))
        end
    end
    return
end

function copy_constraints!(dest::Formulation, src::Formulation, uids;
        copy_membership = true)
    for uid in uids
        if copy_membership
            register_constraint!(dest, uid, getconstrsense(src, uid), 
                getconstrrhs(src, uid), copy(getconstrmembership(src, uid)))
        else
            error("TODO")
        end
    end
end
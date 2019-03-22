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

function Memberships()
    var_m = Dict{VarId, SparseVector{Float64, ConstrId}}()
    constr_m = Dict{ConstrId, SparseVector{Float64, VarId}}()
    return Memberships(var_m, constr_m)
end

function add_variable!(m::Memberships, var::Variable)
    var_uid = getuid(var)
    m.var_memberships[var_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_variable!(m::Memberships,  var_uid::VarId)
    m.var_memberships[var_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_variables!(m::Memberships, vars::Vector{Variable}, 
        memberships::Vector{SparseVector})
    println("\e[31m register vars membership \e[00m")
end

# FVR better todefine add_constrait :one at a time
function add_constraints!(m::Memberships,
                          constr_uid::ConstrId, 
                          membership::SparseVector) 
    m.constr_memberships[constr_uid] = membership
    var_uids, vals = findnz(membership) # FVR membership should hold only non zeros
    for j in 1:length(var_uids)
        m.var_memberships[var_uids[j]][constr_uid] = vals[j]
    end
    return
end

function add_constraints!(m::Memberships, constrs::Vector{Constraint}, 
                          memberships::Vector{SparseVector}) 
    for i in 1:length(constrs)
        constr_uid = getuid(constrs[i])
        m.constr_memberships[constr_uid] = memberships[i]
        var_uids, vals = findnz(memberships[i]) # FVR memberships[i] should hold only non zeros
        for j in 1:length(var_uids)
            m.var_memberships[var_uids[j]][constr_uid] = vals[j]
        end
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

function register_variables!(f::Formulation,
                             vars::Vector{Variable}, 
                             costs::Vector{Float64},
                             lb::Vector{Float64},
                             ub::Vector{Float64}, 
                             vtypes::Vector{VarType})
    @assert length(vars) == length(costs) == length(ub)
    @assert length(vars) == length(lb) == length(vtypes)
    for i in 1:length(vars)
        uid = getuid(vars[i])
        add_variable!(f.memberships, uid) # FVR
        #add_variable!(f.memberships, vars[i])
        # register in manager #FVR already done in  register_objective_sense!(
        # if f.obj_sense == Max
        #     f.costs[uid] = -1.0 * costs[i]
        # else
        #     f.costs[uid] = costs[i]
        # end
        f.costs[uid] = costs[i]
        f.lower_bounds[uid] = lb[i]
        f.upper_bounds[uid] = ub[i]
        # vtypes
    end
    return
end

function register_constraints!(f::Formulation,
                               constrs::Vector{Constraint},
                               memberships::Vector{SparseVector},
                               csenses::Vector{ConstrSense},
                               rhs::Vector{Float64})
    @assert length(constrs) == length(memberships) == length(csenses) == length(rhs)
    # register in manager
    for i in 1:length(constrs)
        uid = getuid(constrs[i])
        f.rhs[uid] = rhs[i]
        f.constr_senses[uid] = csenses[i]
        if csenses[i] == Less
            memberships[i] *= -1.0
            rhs[i] *= -1.0
        end
        add_constraints!(f.memberships, uid, memberships[i])

    end
    #   add_constraints!(f.memberships, constrs, memberships) #FVR
    return
end

function register_objective_sense!(f::Formulation, min::Bool)
    if !min
        m.obj_sense = Max
        m.costs *= -1.0
    end
    return
end

mutable struct Reformulation <: AbstractFormulation
    #solution_method::AbstractSolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of  MathProgFormulation or Reformulation
end

function Reformulation()
    return Reformulation(nothing, nothing, Vector{AbstractFormulation}())
end

function setmaster!(r::Reformulation, f)
    r.master = f
    return
end

function add_dw_pricing_sp!(r::Reformulation, f)
    push!(r.dw_pricing_subprs, f)
    return
end

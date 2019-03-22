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

mutable struct Reformulation <: AbstractFormulation
    solution_method::SolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  Formulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of  MathProgFormulation or Reformulation
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
                            var::Variable, 
                            cost::Float64,
                            lb::Float64, 
                            ub::Float64, 
                            vtype::VarType)
    uid = getuid(var)
    add_variable!(f.memberships, uid)
    f.costs[uid] = cost
    f.lower_bounds[uid] = lb
    f.upper_bounds[uid] = ub
    # TODO : Register in manager
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
                              constr::Constraint,
                              membership::SparseVector,
                              csense::ConstrSense,
                              rhs::Float64)
    uid = getuid(constr)
    f.rhs[uid] = rhs
    f.constr_senses[uid] = csense
    # TODO : register in manager
    add_constraint!(f.memberships, uid, membership)
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
        register_constraint!(f, constrs[i], memberships[i], csenses[i], rhs[i])
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


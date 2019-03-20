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

function add_variables!(m::Memberships, vars::Vector{Variable}, 
        memberships::Vector{SparseVector})
    println("\e[31m register vars membership \e[00m")
end

function add_constraints!(m::Memberships, constrs::Vector{Constraint}, 
        memberships::Vector{SparseVector})
    for i in 1:length(constrs)
        constr_uid = getuid(constrs[i])
        m.constr_memberships[constr_uid] = memberships[i]
        var_uids, vals = findnz(memberships[i])
        for j in 1:length(var_uids)
            m.var_memberships[var_uids[j]][constr_uid] = vals[j]
        end
    end
    return
end

struct Formulation  <: AbstractFormulation
    uid::FormId
    moi_model::MOI.ModelLike
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing} # why nothing ?
    #var_manager::Manager{Variable}
    #constr_manager::Manager{Constraint}
    memberships::Memberships
    #costs::SparseVector{Float64, Int}
    #lower_bounds::SparseVector{Float64, Int}
    #upper_bounds::SparseVector{Float64, Int}
    #rhs::SparseVector{Float64, Int}
    callbacks
end

function Formulation(m::AbstractModel, moi::MOI.ModelLike)
    uid = getnewuid(m.form_counter)
    #v_man = Manager(Variable)
    #c_man = Manager(Constraint)
    return Formulation(uid, moi, nothing, Memberships(), nothing)#v_man, c_man, Memberships())
end

function register_variables!(f::Formulation, vars::Vector{Variable}, 
        costs::Vector{Float64}, lb::Vector{Float64}, ub::Vector{Float64}, 
        vtypes::Vector{VarType})
    @assert length(vars) == length(costs) == length(ub)
    @assert length(vars) == length(lb) == length(vtypes)
    for var in vars
        uid = getuid(var)
        add_variable!(f.memberships, var)
        # register in manager
        # store costs, lb, ub, vtypes
    end
    return
end

function register_constraints!(f::Formulation, constrs::Vector{Constraint},
        memberships::Vector{SparseVector}, csenses::Vector{ConstrSense},
        rhs::Vector{Float64})
    @assert length(constrs) == length(memberships) == length(csenses) == length(rhs)
    # register in manager
    # store constraints senses
    # store rhs
    add_constraints!(f.memberships, constrs, memberships)
    return
end

struct Reformulation <: AbstractFormulation
    solution_method::AbstractSolutionMethod
    parent::Union{Nothing, AbstractFormulation} # reference to (pointer to) ancestor:  MathProgFormulation or Reformulation
    master::Union{Nothing, Formulation}
    dw_pricing_subprs::Vector{AbstractFormulation} # vector of  MathProgFormulation or Reformulation
end




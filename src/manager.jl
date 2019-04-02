# struct Manager{Id <: AbstractVarConstrId, T} <: AbstractManager
#     members::Dict{Id,T}
# end

# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:AbstractVarConstrId,
#          <:Pair{<:AbstractVarConstr, <:AbstractVarConstrInfo}})::Bool

_active_(id_info::Pair{<:AbstractVarConstrId,
                       <:Pair{<:AbstractVarConstr, <:AbstractVarConstrInfo}}
         ) = id_info[2][2].cur_status == Active

struct Manager{VC <: AbstractVarConstr,
               Id <: AbstractVarConstrId,
               Info <: AbstractVarConstrInfo} <: AbstractManager
    members::Dict{Id,Pair{VC,Info}}
end

Manager(::Type{Variable}) = Manager(
    Dict{Id{MoiVarIndex},Pair{Variable,VarInfo}}()
)

Manager(::Type{Constraint}) = Manager(
    Dict{Id{MoiConstrIndex},Pair{Constraint,ConstrInfo}}()
)

has(m::Manager, id::AbstractVarConstrId) = haskey(m.members, id)

get(m::Manager, id::AbstractVarConstrId) = m.members[id]

get(m::Manager, uid::Int) = m.members[Id(uid)]

getvarconstr(m::Manager, id::AbstractVarConstrId) = m.members[id][1]

getvarconstr_info(m::Manager, id::AbstractVarConstrId) = m.members[id][2]

getids(m::Manager) = collect(keys(m.members))

getvarconstr(e::Pair{Id,Pair{VC,Info}}) where {Id, VC, Info} = e[2][1]

Base.filter(f::Function, m::Manager) = filter(f, m.members)

function add!(m::Manager, vc::AbstractVarConstr)
    id = getid(vc)
    m.members[id] = Pair(vc, infotype(typeof(vc))(vc))
    return
end

function Base.show(io::IO, m::Manager)
    println(io, typeof(m), ":")
    for e in m.members
        println(io, "  ", e)
    end
    return
end


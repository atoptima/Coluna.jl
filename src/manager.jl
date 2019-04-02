# struct Manager{Id <: AbstractVarConstrId, T} <: AbstractManager
#     members::Dict{Id,T}
# end

# Define default functions to use as filters
# Functions must be of the form:
# f(::Pair{<:AbstractVarConstrId,
#          <:Pair{<:AbstractVarConstr, <:AbstractVarConstrInfo}})::Bool


struct Manager{VC <: AbstractVarConstr,
               Id <: AbstractVarConstrI} <: AbstractManager
    members::Dict{Id,VC}
end

Manager(::Type{Variable}) = Manager(
    Dict{Id{MoiVarIndex, VarInfo}, Variable}()
)

Manager(::Type{Constraint}) = Manager(
    Dict{Id{MoiConstrIndex, ConstrInfo}, Constraint}()
)

has(m::Manager, id::AbstractVarConstrId) = haskey(m.members, id)

get(m::Manager, id::AbstractVarConstrId) = m.members[id]

get(m::Manager, uid::Int) = m.members[Id(uid)]



getids(m::Manager) = collect(keys(m.members))

getvarconstr(e::Pair{Id,VC}) where {Id, VC} = e[2]

Base.filter(f::Function, m::Manager) = filter(f, m.members)

function add!(m::Manager, id::Id, vc::AbstractVarConstr)
    m.members[id] = vc
    return
end

function Base.show(io::IO, m::Manager)
    println(io, typeof(m), ":")
    for e in m.members
        println(io, "  ", e)
    end
    return
end


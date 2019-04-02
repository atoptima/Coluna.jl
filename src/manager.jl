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
getvarconstr(m::Manager, id::AbstractVarConstrId) = m.members[id][1]
getids(m::Manager) = keys(m.members)
getvarconstr(e::Pair{Id,Pair{VC,Info}}) where {Id, VC, Info} = e[2][1]

Base.filter(f::Function, m::Manager) = filter(f, m.members)

function add!(m::Manager, vc::AbstractVarConstr)
    id = getid(vc)
    m.members[id] = Pair(vc, infotype(typeof(vc))(vc))
    return
end



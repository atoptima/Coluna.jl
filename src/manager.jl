struct Manager{VC <: AbstractVarConstr,
               VCId <: AbstractVarConstrId,
               VCInfo <: AbstractVarConstrInfo} <: AbstractManager
    members::Dict{VCid,Pair{VC,VCInfo}}
end

Manager(::Type{Variable}) = Manager(
    Dict{VarId,Pair{Variable,VarInfo}}()
)

Manager(::Type{Constraint}) = Manager(
    Dict{ConstrId,Pair{Constraint,ConstrInfo}}()
)

idexists(m::Manager, id::AbstractVarConstrId) = haskey(m.members, id)
getvc(m::Manager, id::AbstractVarConstrId) = m.members[id].first
getinfo(m::Manager, id::AbstractVarConstrId) = m.members[id].second
Base.filter(m::Manager, f::Function) = filter(f, m.members)

function add!(vcm::Manager, vc::AbstractVarConstr)
    uid = getuid(vc)
    vcm.members[uid] = Pair(vc, default_info(vc))
    return
end


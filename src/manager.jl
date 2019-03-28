struct Manager{T <: AbstractVarConstr} <: AbstractManager
    members::SparseVector{T,Int}
end

Manager(T::Type{<:AbstractVarConstr}) = Manager{T}(spzeros(MAX_SV_ENTRIES))
getvc(m::Manager, uid::Int) = m.members[uid]

function get_nz_ids(m::Manager)
    return findnz(m.members)[1]
end

function add!(vm::Manager, vc::T) where T <: Union{Variable, Constraint}
    uid = getuid(vc)
    vm.members[uid] = vc
    return
end

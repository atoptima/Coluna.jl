struct Manager{T <: AbstractVarConstr} <: AbstractManager
    members::SparseVector{T,Int}
    duty_sets::Dict{Type{<: AbstractDuty}, Vector{Int}}
end

Manager(T::Type{<:AbstractVarConstr}) = Manager{T}(
    spzeros(MAX_SV_ENTRIES), Dict{Type{<: AbstractDuty}, Vector{Int}}()
)
getvc(m::Manager, uid::Int) = m.members[uid]

function get_nz_ids(m::Manager)
    return findnz(m.members)[1]
end

function add!(vcm::Manager, vc::T) where T <: Union{Variable, Constraint}
    uid = getuid(vc)
    vcm.members[uid] = vc

    duty = getduty(vc)
    if haskey(vcm.duty_sets, duty)
        set = vcm.duty_sets[duty]
    else
        set = vcm.duty_sets[duty] = Vector{Int}()
    end
    push!(set, uid)

    return
end




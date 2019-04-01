struct Manager{T <: AbstractVarConstr} <: AbstractManager
    members::SparseVector{T,Int} # key is uid, field is VarConstr
    per_duty::Dict{Type{<: AbstractDuty}, Vector{Int}}
    filters::Dict{Function,Filter}
end

Manager(T::Type{<:AbstractVarConstr}) = Manager{T}(
    spzeros(MAX_SV_ENTRIES),
    spzeros(MAX_SV_ENTRIES),
    spzeros(MAX_SV_ENTRIES),
    Dict{Type{<: AbstractDuty}, Vector{Int}}(),
    Dict{Function,Filter}())

getvc(m::Manager, uid::Int) = m.members[uid]

getuids(m::Manager, d::Type{<:AbstractDuty}) = m.per_duty[d]

function getuids(m::Manager, f::Function)
    haskey(m.filters, f) && return get_nz_ids(m.filters[f])
    fi = m.filters[f] = Filter(f, m.members)
    return get_nz_ids(fi)
end

getuids(m::Manager, d::Type{<:AbstractDuty}, f::Function) = findnz(apply_mask(
    m.filters[f], m.per_duty[d]))

get_nz_ids(m::Manager) = findnz(m.members)[1]

function add_filter!(m::Manager, f::Function)
    haskey(m.filters, f) && return
    m.filters[f] = Filter(f, m.members)
end

function add!(vcm::Manager, vc::T) where T <: Union{Variable, Constraint}
    uid = getuid(vc)

    vcm.members[uid] = vc
    vcm.flags[uid] = vc.flag
    vcm.status[uid] = Active

    duty = getduty(vc)
    if haskey(vcm.per_duty, duty)
        set = vcm.per_duty[duty]
    else
        set = vcm.per_duty[duty] = Vector{Int}()
    end
    push!(set, uid)
    return
end


mutable struct Filter
    used_mask::SparseVector{Bool,Int}
    active_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
    artificial_mask::SparseVector{Bool,Int}
    implicit_mask::SparseVector{Bool,Int}
end

Filter() = Filter(spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES),
                  spzeros(MAX_SV_ENTRIES))

activemask(f::Filter) = f.used_mask .& f.active_mask
staticmask(f::Filter) = f.used_mask .& f.static_mask
dynamicmask(f::Filter) = f.used_mask .& !f.static_mask
realmask(f::Filter) = f.used_mask .& !f.artificial_mask
artificalmask(f::Filter) = f.used_mask .& f.artificial_mask
implicitmask(f::Filter) = f.used_mask .& f.implicit_mask
explicitmask(f::Filter) = f.used_mask .& !f.implicit_mask
#selectivemask(f::Filter, active::Bool, static::Bool, artificial::Bool) = f.used_mask active ? .& f.active_mask : nothing  static ? .& f.static_mask : nothing  artificial ? .& f.artificial_mask : nothing


struct VarMembership <: AbstractMembership
    members::Dict{VarId, Float64}    #SparseVector{Float64, VarId}
end
function VarMembership()
    return VarMembership(Dict{VarId, Float64}())
end


struct ConstrMembership <: AbstractMembership
    members::Dict{ConstrId, Float64} #SparseVector{Float64, ConstrId}
end

function ConstrMembership()
    return ConstrMembership(Dict{ConstrId, Float64}())
end

function add!(m::AbstractMembership, varconst_id, val::Float64)
    if haskey(m.members, varconst_id)
        # if (reset)
        #    m.members[varconst_id] = val
        # else            
        m.members[varconst_id] += val
    else
        m.members[varconst_id] = val
    end
    return
end

function set!(m::AbstractMembership, varconst_id, val::Float64)
       m.members[varconst_id] = val
    return
end


struct VarManager <: AbstractManager
    members::SparseVector{Variable,VarId}
    status::Filter
    duty_sets::Dict{VarDuty, Vector{VarId}}
end

function VarManager()
    return VarManager(spzeros(MAX_SV_ENTRIES), #SparseVector{Constraint,ConstrId}(),
                      Filter(),
                      Dict{VarDuty, Vector{VarId}}())
end

struct ConstrManager <: AbstractManager
    members::SparseVector{Constraint,ConstrId} # Dict{ConstrId, Constraint}
    status::Filter
    duty_sets::Dict{ConstrDuty, Vector{ConstrId}}
end

function ConstrManager()
    return ConstrManager(spzeros(MAX_SV_ENTRIES), #SparseVector{Variable,VarId}()
                         Filter(),
                         Dict{ConstrDuty, Vector{ConstrId}}())
end

function add!(vm::VarManager, var::Variable)
    var_uid = getuid(var)
    vm.members[var_uid] = var
    vm.status.used_mask[var_uid] = true
    vm.status.active_mask[var_uid] = true
    if (var.flag == Static)
        vm.status.static_mask[var_uid] = true
    elseif (var.flag == Artificial)
        vm.status.artificial_mask[var_uid] = true
    elseif (var.flag == Implicit)
        vm.status.implicit_mask[var_uid] = true
    end
    duty = getduty(var)
    if haskey(vm.duty_sets, duty)   
       set = vm.duty_sets[duty]
    else
        set = vm.duty_sets[duty] = Vector{VarId}()
    end
    push!(set, var_uid)

    return
end


function getvc(m::VarManager,  varconstrId::VarId)
    #!haskey(m.members, varconstrId) && error("manaer does not contain varconstr $varconstrId")
    return m.members[varconstrId]
end

function getvc(m::ConstrManager, varconstrId::ConstrId)
   # !haskey(m.members, varconstrId) && error("manaer does not contain varconstr $varconstrId")
    return m.members[varconstrId]
end


function add!(cm::ConstrManager, constr::Constraint)
    constr_uid = getuid(constr)
    cm.members[constr_uid] = constr
    cm.status.used_mask[constr_uid] = true
    cm.status.active_mask[constr_uid] = true
    if (constr.flag == Static)
        cm.status.static_mask[constr_uid] = true
    elseif (constr.flag == Implicit)
        cm.status.implicit_mask[constr_uid] = true
    end

    duty = getduty(constr)
    if haskey(cm.duty_sets, duty)   
        set = cm.duty_sets[duty]
    else
        set = cm.duty_sets[duty] = Vector{ConstrId}()
    end
    push!(set, constr_uid)
    return
end
   

function get_ids_vals(m::VarMembership)
    #return findnz(m)
    uids = Vector{VarId}()
    vals = Vector{Float64}()
    for (uid,val) in m.members
        push!(uids, uid)
        push!(vals, val)
    end
    return uids, vals
end

function get_ids_vals(m::ConstrMembership)
    #return findnz(m)
    uids = Vector{ConstrId}()
    vals = Vector{Float64}()
    for (uid,val) in m.members
        push!(uids, uid)
        push!(vals, val)
    end
    return uids, vals
end

struct Memberships
    var_to_constr_members::Dict{VarId, ConstrMembership}
    constr_to_var_members::Dict{ConstrId, VarMembership}
    var_to_partialsol_members::Union{Nothing,Dict{VarId, VarMembership}}
    partialsol_to_var_members::Union{Nothing,Dict{VarId, VarMembership}}
    var_to_expression_members::Union{Nothing,Dict{VarId, VarMembership}}
    expression_to_var_members::Union{Nothing,Dict{VarId, VarMembership}}
end

function Memberships()
    var_m = Dict{VarId, ConstrMembership}()
    constr_m = Dict{ConstrId, ConstrMembership}()
    return Memberships(var_m, constr_m, nothing, nothing, nothing, nothing)
end

#function add_var!(m::VarMembership, var_uid::VarId, val::Float64)
#    m[var_uid] = val
#end

#function add_constr!(m::ConstrMembership, constr_uid::VarId, val::Float64)
#    m[constr_uid] = val
#end


hasvar(m::Memberships, uid) = haskey(m.var_to_constr_members, uid)
hasconstr(m::Memberships, uid) = haskey(m.constr_to_var_members, uid)
hasexpression(m::Memberships, uid) = haskey(m.var_to_expression_members, uid)
haspartialsol(m::Memberships, uid) = haskey(m.var_to_partialsol_members, uid)

function get_constr_members_of_var(m::Memberships, uid::VarId) 
    hasvar(m, uid) && return m.var_to_constr_members[uid]
    error("Variable $uid not stored in formulation.")
end

function add_constr_members_of_var!(m::Memberships, var_uid::VarId, new_membership::ConstrMembership) 

    if !haskey(m.var_to_constr_members, var_uid)
        m.var_to_constr_members[var_uid] = ConstrMembership()
    end

    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        add!(m.var_to_constr_members[var_uid], constr_uids[j], vals[j])
        if !haskey(m.constr_to_var_members, constr_uids[j])
            m.constr_to_var_members[constr_uids[j]] = VarMembership()
        end
        add!(m.constr_to_var_members[constr_uids[j]], var_uid, vals[j])
    end
end

function add_var_members_of_constr!(m::Memberships, constr_uid::ConstrId, new_membership::VarMembership) 

    if !haskey(m.constr_to_var_members, constr_uid)
        m.constr_to_var_members[constr_uid] = VarMembership()
    end

    var_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(var_uids)
        add!(m.constr_to_var_members[constr_uid], var_uids[j], vals[j])
        if !haskey(m.var_to_constr_members, var_uids[j])
            m.var_to_constr_members[var_uids[j]] = ConstrMembership()
        end
        add!(m.var_to_constr_members[var_uids[j]], constr_uid, vals[j])
    end
end

function add_partialsol_members_of_var!(m::Memberships, var_uid::VarId, new_membership::VarMembership) 

    if !haskey(m.var_to_partialsol_members, var_uid)
        m.var_to_partialsol_members[var_uid] = VarMembership()
    end
    
    var_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(var_uids)
        add!(m.var_to_partialsol_members[var_uid], var_uids[j], vals[j])
        if !haskey(m.partialsol_to_var_members, var_uids[j])
            m.partialsol_to_var_members[var_uids[j]] = VarMembership()
        end
        add!(m.partialsol_to_var_members[var_uids[j]], var_uid, vals[j])
    end
end

function reset_constr_members_of_var!(m::Memberships, var_uid::VarId, new_membership::ConstrMembership) 
    m.var_to_constr_members[var_uid] = ConstrMembership() #spzeros(MAX_SV_ENTRIES)
    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        set!(m.var_to_constr_members[var_uid],constr_uids[j], vals[j])
    end   
end

function reset_var_members_of_constr!(m::Memberships, constr_uid::ConstrId, new_membership::VarMembership) 
    m.constr_to_var_members[constr_uid] = VarMembership() #spzeros(MAX_SV_ENTRIES)
    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        set!(m.constr_to_var_members[constr_uid], var_uids[j], vals[j])
    end
end

function set_constr_members_of_var!(m::Memberships, var_uid::VarId, new_membership::ConstrMembership) 
    m.var_to_constr_members[var_uid] = ConstrMembership() #spzeros(MAX_SV_ENTRIES)
    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        add!(m.var_to_constr_members[var_uid],constr_uids[j], vals[j])
        if !hasconstr(m, constr_uids[j])
            m.constr_to_var_members[constr_uids[j]] = VarMembership() #spzeros(MAX_SV_ENTRIES)
        end
        add!(m.constr_to_var_members[constr_uids[j]], var_uid, vals[j])
    end
end

function set_var_members_of_constr!(m::Memberships, constr_uid::ConstrId, new_membership::VarMembership) 
    m.constr_to_var_members[constr_uid] = VarMembership() #spzeros(MAX_SV_ENTRIES)
    var_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(var_uids)
        add!(m.constr_to_var_members[constr_uid],var_uids[j], vals[j])
        if !hasvar(m, var_uids[j])
            m.var_to_constr_members[var_uids[j]] = ConstrMembership() #spzeros(MAX_SV_ENTRIES)
        end
        add!(m.var_to_constr_members[var_uids[j]], constr_uid, vals[j])
    end
end

function get_var_members_of_constr(m::Memberships, uid::ConstrId) 
    hasconstr(m, uid) && return m.constr_to_var_members[uid]
    error("Constraint $uid not stored in formulation.")
end

function get_var_members_of_expression(m::Memberships, uid::VarId) 
    hasexpression(m, uid) && return m.var_to_expression_members[uid]
    error("Expression $uid not stored in formulation.")
end

function add_variable!(m::Memberships, var_uid::VarId)
    hasvar(m, var_uid) && error("Variable with uid $var_uid already registered.")
    m.var_to_constr_members[var_uid] = ConstrMembership() #spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_variable!(m::Memberships, var_uid::VarId, constr_membership::SparseVector)
    hasvar(m, var_uid) && error("Variable with uid $var_uid already registered.")
    set_constr_members_of_var!(m, var_uid, constr_membership)
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId)
    hasconstr(m, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    m.constr_to_var_members[constr_uid] = VarMembership() #spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId, membership::VarMembership) 
    hasconstr(m, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    add_var_members_of_constr!(m, constr_uid, membership)
    return
end

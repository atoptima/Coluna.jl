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

function get_nz_ids(m::AbstractManager)
    return findnz(m.members)[1]
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
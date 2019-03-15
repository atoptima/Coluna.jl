struct Variable{DutyType <: AbstractVarDuty}
    uid::VarId # unique id
    moi_id::Int  # -1 if not explixitly in a formulation
    name::Symbol
    duty::DutyType
    formulation::Formulation
    cost::Float64
    # ```
    # sense : 'P' = positive
    # sense : 'N' = negative
    # sense : 'F' = free
    # ```
    sense::Char
    # ```
    # 'C' = continuous,
    # 'B' = binary, or
    # 'I' = integer
    vc_type::Char
    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # 'a' for artificial VarConstr.
    # ```
    flag::Char
    lower_bound::Float64
    upper_bound::Float64
    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    # ```
    # 'U' or 'D'
    # ```
    directive::Char
    # ```
    # A higher priority means that var is selected first for branching or diving
    # ```
    priority::Float64
    status

    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    constr_membership::ConstrMembership
end

function add_var_in_manager(var_manager::VarManager, var::Variable)
    if var.status == Active && var.flag == 's'
        list = var_manager.active_static_list
    elseif var.status == Active && var.flag == 'd'
        list = var_manager.active_dynamic_list
    elseif var.status == Unsuitable && var.flag == 's'
        list = var_manager.unsuitable_static_list
    elseif var.status == Unsuitable && var.flag == 'd'
        list = var_manager.unsuitable_dynamic_list
    else
        error("Status $(var.status) and flag $(var.flag) are not supported")
    end
    list[var.uid] = var.moi_id
end


function remove_from_var_manager(var_manager::VarManager,
        var::Variable)
    if var.status == Active && var.flag == 's'
        list = var_manager.active_static_list
    elseif var.status == Active && var.flag == 'd'
        list = var_manager.active_dynamic_list
    elseif var.status == Unsuitable && var.flag == 's'
        list = var_manager.unsuitable_static_list
    elseif var.status == Unsuitable && var.flag == 'd'
        list = var_manager.unsuitable_dynamic_list
    else
        error("Status $(var.status) and flag $(var.flag) are not supported")
    end
     deleteat!(list, var.uid)
end

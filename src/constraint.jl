
struct Constraint{DutyType <: AbstractConstrDuty}
    uid::ConstrId  # unique id
    moi_id::Int # -1 if not explixitly in a formulation
    name::Symbol
    duty::DutyType
    formulation::Formulation
    vc_ref::Int
    rhs::Float64
    # ```
    # sense : 'G' = greater or equal to
    # sense : 'L' = less or equal to
    # sense : 'E' = equal to
    # ```
    sense::Char
    # ```
    # vc_type = 'C' for core -required for the IP formulation-,
    # vc_type = 'F' for facultative -only helpfull to tighten the LP approximation of the IP formulation-,
    # vc_type = 'S' for constraints defining a subsystem in column generation for
    #            extended formulation approach
    # vc_type = 'M' for constraints defining a pure master constraint
    # vc_type = 'X' for constraints defining a subproblem convexity constraint in the master
    # ```
    vc_type::Char
    # ```
    # 's' -by default- for static VarConstr belonging to the problem -and erased
    #     when the problem is erased-
    # 'd' for dynamically generated VarConstr not belonging to the problem at the outset
    # ```
    flag::Char
    # ```
    # Active = In the formulation
    # Inactive = Can enter the formulation, but is not in it
    # Unsuitable = is not valid for the formulation at the current node.
    # ```
    status
    # ```
    # Represents the membership of a VarConstr as map where:
    # - The key is the index of a constr/var including this as member,
    # - The value is the corresponding coefficient.
    # ```
    var_memvership::VarMembership
end

function add_constr_in_manager(constr_manager::ConstrManager,
                            constr::Constraint)

    if constr.status == Active && constr.flag == 's'
        list = constr_manager.active_static_list
    elseif constr.status == Active && constr.flag == 'd'
        list = constr_manager.active_dynamic_list
    elseif constr.status == Unsuitable && constr.flag == 's'
        list = constr_manager.unsuitable_static_list
    elseif constr.status == Unsuitable && constr.flag == 'd'
        list = constr_manager.unsuitable_dynamic_list
    else
        error("Status $(constr.status) and flag $(constr.flag) are not supported")
    end
    list[constr.uid] = constr.moi_id

end

function remove_from_constr_manager(constr_manager::ConstrManager,
        constr::Constraint)
    if constr.status == Active && constr.flag == 's'
        list = constr_manager.active_static_list
    elseif constr.status == Active && constr.flag == 'd'
        list = constr_manager.active_dynamic_list
    elseif constr.status == Unsuitable && constr.flag == 's'
        list = constr_manager.unsuitable_static_list
    elseif constr.status == Unsuitable && constr.flag == 'd'
        list = constr_manager.unsuitable_dynamic_list
    else
        error("Status $(constr.status) and flag $(constr.flag) are not supported")
    end
     deleteat!(list, constr.uid)
end

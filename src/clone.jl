function clone_in_formulation!(dest::Formulation,
                               id::Id,
                               varconstr::VC,
                               duty::Type{<:AbstractDuty}) where {VC <: AbstractVarConstr}
    #println("cloning a ", VC)
    varconstr_clone = deepcopy(varconstr)
    setform!(varconstr_clone, getuid(dest))
    id_clone = Id(getuid(id), statetype(VC)(duty, varconstr_clone))
    add!(dest, varconstr_clone, id_clone)
    #@show id_clone
    return id_clone
end

# function clone_in_formulation!(dest::Formulation,
#                                src::Formulation,
#                                id::Id{VarState},
#                                var::Variable,
#                                duty::Type{<: AbstractVarDuty})
#     id_clone = clone_in_formulation!(dest, id, var, duty)
#     set_constr_members_of_var!(dest.memberships, id_clone,
#         deepcopy(get_constr_members_of_var(src, id)))
#     return id_clone
# end

# function clone_in_formulation!(dest::Formulation,
#                                src::Formulation,
#                                id::Id{ConstrState},
#                                constr::Constraint,
#                                duty::Type{<: AbstractConstrDuty})
#     id_clone = clone_in_formulation!(dest, id, constr, duty)
#     set_var_members_of_constr!(dest.memberships, id_clone,
#         deepcopy(get_var_members_of_constr(src, id)))
#     return id_clone
# end

# TODO :facto
function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               vcs::VcDict{S,VC}, 
                               duty) where {S<:AbstractState,
                                            VC<:AbstractVarConstr}
    for (id, vc) in vcs
        clone_in_formulation!(dest, id, vc, duty)
    end
    return
end

function clone_memberships!(dest::Formulation,
                            src::Formulation)
    dest_memberships = get_memberships(dest)
    for (dest_var_id, var) in getvars(dest)
        src_var_id = get_varid_from_uid(src, getuid(dest_var_id))
        src_members = get_constr_members_of_var(src, src_var_id)
        for (src_constr_id, coeff) in src_members
            dest_constr_id = get_constrid_from_uid(dest, getuid(src_constr_id))
            if getuid(dest_constr_id) == -1 # src_constr_id is not in dest
                continue
            end
            set_constr_members_of_var!(
                dest_memberships, dest_var_id, dest_constr_id, coeff
            )
        end
    end
    return
end
function clone_memberships!(dest::Formulation,
                            src::Formulation)
    dest_memberships = get_memberships(dest)
    for (dest_var_id, var) in getvars(dest)
        src_var_id = get_varid_from_uid(src, getuid(dest_var_id))
        src_members = get_constr_members_of_var(src, src_var_id)
        for (src_constr_id, coeff) in src_members
            dest_constr_id = get_constrid_from_uid(dest, getuid(src_constr_id))
            if getuid(dest_constr_id) == -1 # src_constr_id is not in dest
                continue
            end
            set_constr_members_of_var!(
                dest_memberships, dest_var_id, dest_constr_id, coeff
            )
        end
    end
    return
end

# function clone_membership_in_formulation!(dest::Formulation,
#                                           src::Formulation,
#                                           var_id::Id{VarState})
#     for (constr_id, val) in get_constr_members_of_var(src, var_id)
#         add!(dest, var_id, constr_id, val)
#     end
# end

# function clone_membership_in_formulation!(dest::Formulation,
#                                           src::Formulation,
#                                           constr_id::Id{ConstrState})
#     for (var_id, val) in get_var_members_of_constr(src, constr_id)
#         add!(dest, var_id, constr_id, val)
#     end  
# end

# function clone_membership_in_formulation!(dest::Formulation,
#                                           src::Formulation,
#                                           vcs::VcDict{S,VC}) where {S<:AbstractState,
#                                                                     VC<:AbstractVarConstr}
#     for (id, vc) in vcs
#         clone_membership_in_formulation!(dest, src, id)
#     end
#     return
# end

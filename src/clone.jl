function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty})
    var_clone = Variable(
        getid(var), getname(var), duty; var_data = get_initial_data(var)
    )
    add_var!(dest, var_clone)
    clone_in_manager!(dest.manager, src.manager, var_clone)
    return
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constr::Constraint,
                               duty::Type{<:AbstractDuty})

    constr_clone = Constraint(getid(constr),
                              getname(constr),
                              duty;
                              constr_data = get_initial_data(constr))
    add_constr!(dest, constr_clone)
    clone_in_manager!(dest.manager, src.manager, constr_clone)
    return
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               vcs::VarConstrDict,
                               duty::Type{<:AbstractVarConstrDuty}
                               ) where {VC<:AbstractVarConstr}
    for (id, vc) in vcs
        clone_in_formulation!(dest, src, vc, duty)
    end
    return
end

function clone_in_manager!(dest::FormulationManager,
                    src::FormulationManager,
                    var::Variable)
    
    dest.coefficients[:, var.id] = copy(getrecords(src.coefficients[:, var.id]))
    return var
end

function clone_in_manager!(dest::FormulationManager,
                        src::FormulationManager,
                        constr::Constraint)

    dest.coefficients[constr.id, :] = copy(getrecords(src.coefficients[constr.id, :]))

    return constr
end

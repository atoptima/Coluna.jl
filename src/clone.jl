function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty})
    var_clone = Variable(
        getid(var), getname(var), duty; var_data = get_initial_data(var)
    )
    clone_var!(dest, src, var_clone)
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
    clone_constr!(dest, src, constr_clone)
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

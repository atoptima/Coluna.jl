function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty})
    var_clone = Variable(
        getid(var), getname(var), duty;
        var_data = deepcopy(get_initial_data(var))
    )
    add_var!(dest, var_clone)
    clone_in_manager!(dest.manager, src.manager, var_clone)
    return
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constr::Constraint,
                               duty::Type{<:AbstractDuty})

    constr_clone = Constraint(
        getid(constr), getname(constr), duty;
        constr_data = deepcopy(get_initial_data(constr))
    )
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
    
    new_col = Dict{Id{Constraint}, Float64}()
    for (id, val) in getrecords(src.coefficients[:, var.id])
        if has(dest, id)
            new_col[id] = val
        end
    end
    dest.coefficients[:, var.id] = new_col
    return var
end

function clone_in_manager!(dest::FormulationManager,
                        src::FormulationManager,
                        constr::Constraint)

    new_row = Dict{Id{Variable}, Float64}()
    for (id, val) in getrecords(src.coefficients[constr.id, :])
        if has(dest, id)
            new_row[id] = val
        end
    end
    dest.coefficients[constr.id, :] = new_row
    return constr
end

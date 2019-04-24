function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty},
                               is_explicit::Bool = true)
    data = deepcopy(get_initial_data(var))
    set_is_explicit!(data, is_explicit)
    var_clone = Variable(
        get_id(var), get_name(var), duty;
        var_data = data
    )
    add_var!(dest, var_clone)
    clone_in_manager!(dest.manager, src.manager, var_clone)
    return var_clone
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constr::Constraint,
                               duty::Type{<:AbstractDuty},
                               is_explicit::Bool = true)

    data = deepcopy(get_initial_data(constr))
    set_is_explicit!(data, is_explicit)
    constr_clone = Constraint(
        get_id(constr), get_name(constr), duty; constr_data = data
    )
    add_constr!(dest, constr_clone)
    clone_in_manager!(dest.manager, src.manager, constr_clone)
    return constr_clone
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               vcs::VarConstrDict,
                               duty::Type{<:AbstractVarConstrDuty},
                               is_explicit::Bool = true
                               ) where {VC<:AbstractVarConstr}
    for (id, vc) in vcs
        clone_in_formulation!(dest, src, vc, duty, is_explicit)
    end
    return
end

function clone_in_manager!(dest::FormulationManager,
                    src::FormulationManager,
                    var::Variable)
    
    new_col = Dict{Id{Constraint}, Float64}()
    for (id, val) in getrecords(src.coefficients[:, var.id])
        if haskey(dest, id)
            new_col[id] = val
        else
            @debug string("Manager does not have constraint with ", id)
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
        if haskey(dest, id)
            new_row[id] = val
        else
            @debug string("Manager does not have variable with ", id)
        end
    end
    dest.coefficients[constr.id, :] = new_row
    return constr
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty})


    var_clone = deepcopy(var)
    reset!(var_clone)
    var_clone.id.form_uid = getuid(dest)
    setduty(var_clone, duty)
    
    return clone_var!(dest, src, var_clone)
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constr::Constraint,
                               duty::Type{<:AbstractDuty})


    constr_clone = deepcopy(constr)
    reset!(constr_clone)
    constr_clone.id.form_uid = getuid(dest)
    setduty(constr_clone, duty)
    
    return clone_constr!(dest, src, constr_clone)
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               vars::VarDict, 
                               duty) 
    for (id, var) in vars
        clone_in_formulation!(dest, src, var, duty)
    end
    return
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constrs::ConstrDict, 
                               duty) 
    for (id, constr) in constrs
        clone_in_formulation!(dest, src, constr, duty)
    end
    return
end


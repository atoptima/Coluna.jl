function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty},
                               is_explicit::Bool = true)
    data = deepcopy(getrecordeddata(var))
    set_is_explicit!(data, is_explicit)
    var_clone = Variable(
        getid(var), getname(var), duty;
        var_data = data
    )
    addvar!(dest, var_clone)
    return var_clone
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constr::Constraint,
                               duty::Type{<:AbstractDuty},
                               is_explicit::Bool = true)

    data = deepcopy(getrecordeddata(constr))
    set_is_explicit!(data, is_explicit)
    constr_clone = Constraint(
        getid(constr), getname(constr), duty; constr_data = data
    )
    addconstr!(dest, constr_clone)
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

function clone_coefficients!(dest::Formulation,
                             src::Formulation)
    dest_matrix = getcoefmatrix(dest)
    src_matrix = getcoefmatrix(src)
    for (cid, constr) in getconstrs(dest)
        if haskey(src, cid)
            for (vid, var) in getvars(dest)
                if haskey(src, vid)
                    val = src_matrix[cid, vid]
                    if val != 0
                        dest_matrix[cid, vid] = val
                    end
                end
            end
        end
    end
    return
end
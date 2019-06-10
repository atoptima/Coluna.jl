function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               var::Variable,
                               duty::Type{<:AbstractDuty};
                               name::String = getname(var),
                               cost::Float64 = getperenecost(var),
                               lb::Float64 = getperenelb(var),
                               ub::Float64 = getpereneub(var),
                               kind::VarKind = getperenekind(var),
                               sense::VarSense = getperenesense(var),
                               inc_val::Float64 = getpereneincval(var),
                               is_active::Bool = get_init_is_active(var),
                               is_explicit::Bool = get_init_is_explicit(var))
    v_data = VarData(cost,lb, ub, kind, sense, inc_val, is_active, is_explicit)
    var_clone = Variable(getid(var), getname(var), duty; var_data = v_data)
    addvar!(dest, var_clone)
    return var_clone
end

function clone_in_formulation!(dest::Formulation,
                               src::Formulation,
                               constr::Constraint,
                               duty::Type{<:AbstractDuty};
                               name::String = getname(constr),
                               rhs::Float64 = getperenerhs(constr),
                               kind::ConstrKind = getperenekind(constr),
                               sense::ConstrSense = getperenesense(constr),
                               inc_val::Float64 = getpereneincval(constr),
                               is_active::Bool = get_init_is_active(constr),
                               is_explicit::Bool = get_init_is_explicit(constr))

    c_data = ConstrData(rhs, kind, sense,  inc_val, is_active, is_explicit)
    constr_clone = Constraint(
        getid(constr), getname(constr), duty; constr_data = c_data
    )
    addconstr!(dest, constr_clone)
    return constr_clone
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
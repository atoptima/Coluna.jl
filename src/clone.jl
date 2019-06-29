function clonevar!(dest::Formulation,
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
    return setvar!(
        dest, name, duty; cost = cost, lb = lb, ub = ub, kind = kind, 
        sense = sense, inc_val = inc_val, is_active = is_active,
        is_explicit = is_explicit, id = getid(var)
    )
end

function cloneconstr!(dest::Formulation,
                      constr::Constraint,
                      duty::Type{<:AbstractDuty};
                      name::String = getname(constr),
                      rhs::Float64 = getperenerhs(constr),
                      kind::ConstrKind = getperenekind(constr),
                      sense::ConstrSense = getperenesense(constr),
                      inc_val::Float64 = getpereneincval(constr),
                      is_active::Bool = get_init_is_active(constr),
                      is_explicit::Bool = get_init_is_explicit(constr))
    return setconstr!(
        dest, name, duty, rhs = rhs, kind = kind, sense = sense, 
        inc_val = inc_val, is_active = is_active, is_explicit = is_explicit,
        id = getid(constr)
    )
end

function clonecoeffs!(dest::Formulation,
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

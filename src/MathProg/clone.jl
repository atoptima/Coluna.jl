function clonevar!(
    originform::Formulation,
    destform::Formulation,
    assignedform::Formulation,
    var::Variable,
    duty::Duty{Variable};
    name::String = getname(originform, var),
    cost::Float64 = getperencost(originform, var),
    lb::Float64 = getperenlb(originform, var),
    ub::Float64 = getperenub(originform, var),
    kind::VarKind = getperenkind(originform, var),
    inc_val::Float64 = getperenincval(originform, var),
    is_active::Bool = isperenactive(originform, var),
    is_explicit::Bool = isexplicit(originform, var),
    members::Union{ConstrMembership,Nothing} = nothing
)
    return setvar!(
        destform, name, duty; 
        cost = cost, lb = lb, ub = ub, kind = kind,
        inc_val = inc_val, is_active = is_active, is_explicit = is_explicit, 
        members = members,
        id = Id{Variable}(duty, getid(var), getuid(assignedform))
    )
end

function cloneconstr!(
    originform::Formulation,
    destform::Formulation,
    assignedform::Formulation,
    constr::Constraint,
    duty::Duty{Constraint};
    name::String = getname(originform, constr),
    rhs::Float64 = getperenrhs(originform, constr),
    kind::ConstrKind = getperenkind(originform, constr),
    sense::ConstrSense = getperensense(originform, constr),
    inc_val::Float64 = getperenincval(originform, constr),
    is_active::Bool = isperenactive(originform, constr),
    is_explicit::Bool = isexplicit(originform, constr),
    members::Union{VarMembership,Nothing}  = nothing,
    loc_art_var = false
)
    return setconstr!(
        destform, name, duty;
        rhs = rhs, kind = kind, sense = sense, inc_val = inc_val,
        is_active = is_active, is_explicit = is_explicit, members = members,
        loc_art_var = loc_art_var, id = Id{Constraint}(duty, getid(constr), getuid(assignedform))
    )
end

function clonecoeffs!(originform::Formulation,
                      destform::Formulation)
    dest_matrix = getcoefmatrix(destform)
    orig_matrix = getcoefmatrix(originform)
    for (cid, constr) in getconstrs(destform)
        if haskey(originform, cid)
            for (vid, var) in getvars(destform)
                if haskey(originform, vid)
                    val = orig_matrix[cid, vid]
                    if val != 0
                        dest_matrix[cid, vid] = val
                    end
                end
            end
        end
    end
    return
end

# TODO : these methods should not be part of MathProg.
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
    branching_priority::Float64 = getbranchingpriority(originform, var),
    members::Union{ConstrMembership,Nothing} = nothing
)
    id_of_clone = VarId(
        getid(var);
        duty = duty,
        assigned_form_uid = getuid(assignedform)
    )
    return setvar!(
        destform, name, duty; 
        cost = cost, lb = lb, ub = ub, kind = kind,
        inc_val = inc_val, is_active = is_active, is_explicit = is_explicit, 
        branching_priority = branching_priority, members = members, 
        id = id_of_clone
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
    loc_art_var_abs_cost::Float64 = 0.0
)
    id_of_clone = ConstrId(
        getid(constr);
        duty = duty,
        assigned_form_uid = getuid(assignedform)
    )
    return setconstr!(
        destform, name, duty;
        rhs = rhs, kind = kind, sense = sense, inc_val = inc_val,
        is_active = is_active, is_explicit = is_explicit, members = members,
        loc_art_var_abs_cost = loc_art_var_abs_cost, 
        id = id_of_clone
    )
end
 
function clonesinglevarconstr!(
    originform::Formulation,
    destform::Formulation,
    assignedform::Formulation,
    constr::SingleVarConstraint,
    duty::Duty{Constraint};
    name::String = constr.name, #getname(originform, constr),
    rhs::Float64 = constr.perendata.rhs, #getperenrhs(originform, constr),
    kind::ConstrKind = constr.perendata.kind, #getperenkind(originform, constr),
    sense::ConstrSense = constr.perendata.sense, #getperensense(originform, constr),
    inc_val::Float64 = constr.perendata.inc_val, #getperenincval(originform, constr),
    is_active::Bool = true, #isperenactive(originform, constr),
    is_explicit::Bool = true #isexplicit(originform, constr)
)
    id_of_clone = SingleVarConstrId(
        getid(constr);
        duty = duty,
        assigned_form_uid = getuid(assignedform)
    )
    return setsinglevarconstr!(
        destform, name, constr.varid, duty;
        rhs = rhs, kind = kind, sense = sense, inc_val = inc_val,
        is_active = is_active,
        id = id_of_clone
    )
end

function clonecoeffs!(originform::Formulation, destform::Formulation)
    dest_matrix = getcoefmatrix(destform)
    orig_matrix = getcoefmatrix(originform)
    for (cid, constr) in getconstrs(destform)
        if haskey(originform, cid)
            row = @view orig_matrix[cid, :]
            for (vid, val) in row
                if haskey(destform, vid) && val != 0
                    dest_matrix[cid, getid(getvar(destform, vid))] = val
                end
            end
        end
    end
    return
end

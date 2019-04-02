mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::FormId
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master
    #moi_model::Union{MOI.ModelLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    vars::Manager{Variable, Id{MoiVarIndex}, VarInfo}
    constrs::Manager{Constraint, Id{MoiConstrIndex}, ConstrInfo}
    memberships::Memberships
    obj_sense::ObjSense
    callback
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    primal_solution_record::Union{PrimalSolution, Nothing}
    dual_solution_record::Union{DualSolution, Nothing}
end

function Formulation(Duty::Type{<: AbstractFormDuty},
                     m::AbstractModel, 
                     parent_formulation::Union{AbstractFormulation, Nothing},
                     moi_optimizer::Union{MOI.AbstractOptimizer, Nothing})
    uid = getnewuid(m.form_counter)
    return Formulation{Duty}(uid,
                             parent_formulation,
                             #moi_model,
                             moi_optimizer, 
                             Manager(Variable),
                             Manager(Constraint),
                             Memberships(),
                             Min,
                             nothing,
                             Inf,
                             -Inf,
                             nothing,
                             nothing)
end

function Formulation(Duty::Type{<: AbstractFormDuty},
                     m::AbstractModel, 
                     optimizer::Union{MOI.AbstractOptimizer, Nothing})
    return Formulation(Duty, m, nothing, optimizer)
end

function Formulation(Duty::Type{<: AbstractFormDuty}, m::AbstractModel, 
                     parent_formulation::Union{AbstractFormulation, Nothing})
    return Formulation(Duty, m, parent_formulation, nothing)
end

function Formulation(Duty::Type{<: AbstractFormDuty}, m::AbstractModel)
    return Formulation(Duty, m, nothing, nothing)
end

#getvarcost(f::Formulation, uid) = f.costs[uid]
#getvarlb(f::Formulation, uid) = f.lower_bounds[uid]
#getvarub(f::Formulation, uid) = f.upper_bounds[uid]

#getconstrrhs(f::Formulation, uid) = f.rhs[uid]
#getconstrsense(f::Formulation, uid) = f.constr_senses[uid]



getvar_ids(fo::Formulation, fu::Function) = filter(fu, fo.vars)

getconstr_ids(fo::Formulation, fu::Function) = filter(fu, fo.constrs)

getuid(f::Formulation) = f.uid

getvar(f::Formulation, id::Id) = get(f.vars, id)

getconstr(f::Formulation, id::Id) = get(f.constrs, id)

getvar_ids(f::Formulation) = getids(f.vars)

getconstr_ids(f::Formulation) = getids(f.constrs)

getvar_ids(f::Formulation, d::Type{<:AbstractVarDuty}) = collect(keys(filter(e -> getvarconstr_info(e).duty == d, f.vars)))

getconstr_ids(f::Formulation, d::Type{<:AbstractConstrDuty}) = collect(keys(filter(e -> getvarconstr_info(e).duty == d, f.constrs)))

getvar_ids(f::Formulation, s::Status) = collect(keys(filter(e -> getvarconstr_info(e).cur_status == s, f.vars)))

getconstr_ids(f::Formulation, s::Status) = collect(keys(filter(e -> getvarconstr_info(e).cur_status == s, f.constrs)))

getobjsense(f::Formulation) = f.obj_sense

get_constr_members_of_var(f::Formulation, id::Id) = get_constr_members_of_var(f.memberships, id)

get_var_members_of_constr(f::Formulation, id::Id) = get_var_members_of_constr(f.memberships, id)

get_constr_members_of_var(f::Formulation, var::Variable) = get_constr_members_of_var(f, getid(var))

get_var_members_of_constr(f::Formulation, constr::Constraint) = get_var_members_of_constr(f, getid(constr))

function clone_in_formulation!(varconstr::AbstractVarConstr,
                               src::Formulation,
                               dest::Formulation,
                               flag::Flag,
                               duty::Type{<:AbstractDuty})
    varconstr_copy = copy(varconstr, flag, duty, getuid(dest))
    add!(dest, varconstr_copy)
    return varconstr_copy
end

function clone_in_formulation!(var_ids::Vector{VCid},
                               src_form::Formulation,
                               dest_form::Formulation,
                               flag::Flag,
                               duty::Type{<: AbstractVarDuty}) where {VCid <: Id}
    for var_id in var_ids
        var = getvar(src_form, var_id)
        var_clone = clone_in_formulation!(var, src_form, dest_form, flag, duty)
        reset_constr_members_of_var!(dest_form.memberships, var_id,
                                     get_constr_members_of_var(src_form, var_id))
    end
    return 
end

function clone_in_formulation!(constr_uids::Vector{VCid},
                               src_form::Formulation,
                               dest_form::Formulation,
                               flag::Flag,
                               duty::Type{<: AbstractConstrDuty}) where {VCid <: Id}
    for constr_uid in constr_uids
        constr = getconstr(src_form, constr_uid)
        constr_clone = clone_in_formulation!(constr, src_form, dest_form, flag, duty)
        set_var_members_of_constr!(dest_form.memberships, constr_uid,
                                     get_var_members_of_constr(src_form, constr_uid))
    end
    
    return 
end

#==function clone_in_formulation!(varconstr::AbstractVarConstr, src::Formulation, dest::Formulation, duty; membership = false)
    varconstr_copy = deepcopy(varconstr)
    setform!(varconstr_copy, getuid(dest))
    setduty!(varconstr_copy, duty)
    if membership
        m = get_constr_members(src, varconstr)
        m_copy = deepcopy(m)
        add!(dest, varconstr_copy, m_copy)
    else
        add!(dest, varconstr_copy)
    end
    return
end ==#

function add!(f::Formulation, elems::Vector{VarConstr}) where {VarConstr <: AbstractVarConstr}
    for elem in elems
        add!(f, elem)
    end
    return
end

function add!(f::Formulation, elems::Vector{VarConstr}, 
              memberships::Vector{M}) where {VarConstr <: AbstractVarConstr,
                                                  M <: AbstractMembership}
    @assert length(elems) == length(memberships)
    for i in 1:length(elems)
        add!(f, elems[i], memberships[i])
    end
    return
end

function add!(f::Formulation, var::Variable)
    add!(f.vars, var)
    add_variable!(f.memberships, getid(var)) 
    return
end

function add!(f::Formulation, var::Variable, membership::Membership{Constraint})
    add!(f.vars, var)
    add_variable!(f.memberships, getid(var), membership)
    return
end

function add!(f::Formulation, constr::Constraint)
    add!(f.constrs, constr)
    #f.constr_rhs[getuid(constr)] = constr.rhs
    add_constraint!(f.memberships, getid(constr))
    return
end

function add!(f::Formulation, constr::Constraint, membership::Membership{Variable})
    add!(f.constrs, constr)
    #f.constr_rhs[getuid(constr)] = constr.rhs
    add_constraint!(f.memberships, getid(constr), membership)
    return
end

function register_objective_sense!(f::Formulation, min::Bool)
    # if !min
    #     m.obj_sense = Max
    #     m.costs *= -1.0
    # end
    !min && error("Coluna does not support maximization yet.")
    return
end

function optimize(form::Formulation, optimizer = form.moi_optimizer, update_form = true)    
    call_moi_optimize_with_silence(form.moi_optimizer)
    status = MOI.get(form.moi_optimizer, MOI.TerminationStatus())
    primal_sols = PrimalSolution[]
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)
    if MOI.get(optimizer, MOI.ResultCount()) >= 1
        primal_sol = retrieve_primal_sol(form)
        push!(primal_sols, primal_sol)
        dual_sol = retrieve_dual_sol(form)
        if update_form
            form.primal_solution_record = primal_sol
            if dual_sol != nothing
                dual_solution_record = dual_sol
            end
        end

        return (status, primal_sol.value, primal_sols, dual_sol)
    end
    @logmsg LogLevel(-4) string("Solver has no result to show.")
    return (status, +inf, nothing, nothing)
end

function compute_original_cost(sol::PrimalSolution, form::Formulation)
    cost = 0.0
    for (var_uid, val) in sol.members
        var = getvar(form,var_uid)
        cost += var.cost * val
    end
    @logmsg LogLevel(-4) string("intrinsic_cost = ",cost)
    return cost
end

function _show_obj_fun(io::IO, f::Formulation)
    print(io, getobjsense(f), " ")
    for id in getvar_ids(f)
        var = getvar(f, id)
        name = getname(var)
        cost = getcost(var)
        op = (cost < 0.0) ? "-" : "+" 
        #if cost != 0.0
            print(io, op, " ", abs(cost), " ", name, " ")
        #end
    end
    println(io, " ")
    return
end

function _show_constraint(io::IO, f::Formulation, id)
    constr = getconstr(f, id)
    print(io, " ", getname(constr), " : ")
    membership = get_var_members_of_constr(f, constr)
    var_ids = getids(membership)
    for var_id in sort!(var_ids)
        coeff = membership[var_id]
        if has(f.vars, var_id)
            var = getvar(f, var_id)
            name = getname(var)
            op = (coeff < 0.0) ? "-" : "+"
            print(io, op, " ", abs(coeff), " ", name, " ")
        else
            @warn "Cannot find variable with id $var_id and coeff $coeff which is member of constraint $(getname(constr))"
        end
    end

    if getsense(constr) == Equal
        op = "=="
    elseif getsense(constr) == Greater
        op = ">="
    else
        op = "<="
    end
    print(io, " ", op, " ", getrhs(constr))
    d = getduty(constr)
    println(io, " (", d ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    for id in sort!(getconstr_ids(f))
        _show_constraint(io, f, id)
    end
    return
end

function _show_variable(io::IO, f::Formulation, uid)
    var = getvar(f, uid)
    name = getname(var)
    lb = getlb(var)
    ub = getub(var)
    t = gettype(var)
    d = getduty(var)
    f = getflag(var)
    println(io, lb, " <= ", name, " <= ", ub, " (", t, " | ", d ," | ", f , ")")
end

function _show_variables(io::IO, f::Formulation)
    for id in sort!(getvar_ids(f))
        _show_variable(io, f, id)
    end
end

function Base.show(io::IO, f::Formulation)
    println(io, "Formulation id = ", getuid(f))
    _show_obj_fun(io, f)
    _show_constraints(io, f)
    _show_variables(io, f)
    return
end

mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::FormId
    problem::AbstractProblem
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master
    #moi_model::Union{MOI.ProblemLike, Nothing}
    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    vars::Manager{Id{VarState}, Variable}
    constrs::Manager{Id{ConstrState}, Constraint}
    memberships::Memberships
    obj_sense::ObjSense
    callback
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    primal_solution_record::Union{PrimalSolution, Nothing}
    dual_solution_record::Union{DualSolution, Nothing}
end

function Formulation(Duty::Type{<: AbstractFormDuty},
                     m::AbstractProblem, 
                     parent_formulation::Union{AbstractFormulation, Nothing},
                     moi_optimizer::Union{MOI.AbstractOptimizer, Nothing})
    uid = getnewuid(m.form_counter)
    return Formulation{Duty}(uid,
                             m,
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
                     m::AbstractProblem, 
                     optimizer::Union{MOI.AbstractOptimizer, Nothing})
    return Formulation(Duty, m, nothing, optimizer)
end

function Formulation(Duty::Type{<: AbstractFormDuty}, m::AbstractProblem, 
                     parent_formulation::Union{AbstractFormulation, Nothing})
    return Formulation(Duty, m, parent_formulation, nothing)
end

function Formulation(Duty::Type{<: AbstractFormDuty}, m::AbstractProblem)
    return Formulation(Duty, m, nothing, nothing)
end

#getvarcost(f::Formulation, uid) = f.costs[uid]
#getvarlb(f::Formulation, uid) = f.lower_bounds[uid]
#getvarub(f::Formulation, uid) = f.upper_bounds[uid]

#getconstrrhs(f::Formulation, uid) = f.rhs[uid]
#getconstrsense(f::Formulation, uid) = f.constr_senses[uid]

getvars(f::Formulation) = f.vars
getconstrs(f::Formulation) = f.constrs

getvar_ids(fo::Formulation, fu::Function) = filter(fu, fo.vars)

getconstr_ids(fo::Formulation, fu::Function) = filter(fu, fo.constrs)

getuid(f::Formulation) = f.uid

getvar(f::Formulation, id::Id{VarState}) = get(f, id)
getconstr(f::Formulation, id::Id{ConstrState}) = get(f, id)
getstate(f::Formulation, id::Id{VarState}) = getstate(getkey(f.vars, id, 0)) # TODO change the default value (empty Id)
getstate(f::Formulation, id::Id{ConstrState}) = getstate(getkey(f.constrs, id, 0))

has(f::Formulation, id::Id{VarState}) = has(f.vars, id)
has(f::Formulation, id::Id{ConstrState}) = has(f.constrs, id)
get(f::Formulation, id::Id{VarState}) = get(f.vars, id)
get(f::Formulation, id::Id{ConstrState}) = get(f.constrs, id)

@deprecate getvar get
@deprecate getconstr get

getvar_ids(f::Formulation) = getids(f.vars)

getconstr_ids(f::Formulation) = getids(f.constrs)


#getvar_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}) = collect(keys(get_subset(f.vars, Duty)))

#getconstr_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}) = collect(keys(get_subset(f.vars, Duty)))

#getvar_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}, stat::Status) = collect(keys(get_subset(f.vars, Duty, stat)))

#getconstr_ids(f::Formulation, Duty::Type{<:AbstractVarDuty}, stat::Status) = collect(keys(get_subset(f.vars, Duty, stat)))

#getvar_ids(f::Formulation, stat::Status) = collect(keys(get_subset(f.vars, stat)))

#getconstr_ids(f::Formulation,  stat::Status) = collect(keys(get_subset(f.vars, stat)))

getobjsense(f::Formulation) = f.obj_sense

get_constr_members_of_var(f::Formulation, id::Id) = get_constr_members_of_var(f.memberships, id)

get_var_members_of_constr(f::Formulation, id::Id) = get_var_members_of_constr(f.memberships, id)

function clone_in_formulation!(varconstr::VC,
                               id::Id,
                               dest::Formulation,
                               duty::Type{<:AbstractDuty}) where {VC <: AbstractVarConstr}
    varconstr_clone = deepcopy(varconstr)
    setform!(varconstr_clone, getuid(dest))
    id_clone = Id(getuid(id), infotype(VC)(duty, varconstr_clone))
    add!(dest, varconstr_clone, id_clone)
    return id_clone
end

function clone_in_formulation!(id::Id{VarState},
                               var::Variable,
                               src::Formulation,
                               dest::Formulation,
                               duty::Type{<: AbstractVarDuty})
    id_clone = clone_in_formulation!(var, id, dest, duty)
    reset_constr_members_of_var!(dest.memberships, id_clone,
                                    get_constr_members_of_var(src, id))
    return id_clone
end

function clone_in_formulation!(id::Id{ConstrState},
                               constr::Constraint,
                               src::Formulation,
                               dest::Formulation,
                               duty::Type{<: AbstractConstrDuty})

    id_clone = clone_in_formulation!(constr, id, dest, duty)
    set_var_members_of_constr!(dest.memberships, id_clone,
                               get_var_members_of_constr(src, id))
    return id_clone
end

# TODO :facto
function clone_in_formulation!(vcs::Manager{I,VC},
                               src::Formulation, 
                               dest::Formulation,
                               duty) where {I<:Id,VC<:AbstractVarConstr}
    for (id, vc) in vcs
        clone_in_formulation!(id, vc, src, dest, duty)
    end
    return
end

function clone_in_formulation!(vcs::Vector{Tuple{I,VC}},
                                src::Formulation, 
                                dest::Formulation,
                                duty) where {I<:Id,VC<:AbstractVarConstr}
    for (id, vc) in vcs
        clone_in_formulation!(id, vc, src, dest, duty)
    end
    return
end

function end_clone(dest::Formulation)
    clean(dest, dest.memberships)
    return
end

function clean(f::Formulation, m::Memberships)
    clean(f, m.var_to_constr_members)
    clean(f, m.constr_to_var_members)
    return
end

function clean(f::Formulation, dict)
    for (id, membership) in dict
        clean(f, membership)
    end
    return
end

# TODO : find better name
function clean(f::Formulation, m::Membership)
    idstodelete = Id[]
    for (id, val) in m
        if has(f, id)
            #setstate!(id, getstate(id))
            setstate!(id, getstate(f, id))
        else
            #@warn "Formulation has not id $id"
            push!(idstodelete, id)
        end
    end
    delete!(m.members, idstodelete)
    return
end


# function add!(f::Formulation, elems::Vector{VarConstr}) where {VarConstr <: AbstractVarConstr}
#     for elem in elems
#         add!(f, elem)
#     end
#     return
# end

# function add!(f::Formulation, elems::Vector{VarConstr}, 
#               memberships::Vector{M}) where {VarConstr <: AbstractVarConstr,
#                                                   M <: AbstractMembership}
#     @assert length(elems) == length(memberships)
#     for i in 1:length(elems)
#         add!(f, elems[i], memberships[i])
#     end
#     return
# end

# TODO membership should be an optional arg
function add!(f::Formulation, var::Variable, id::Id{VarState})
    set!(f.vars, id, var)
    add_variable!(f.memberships, id) 
    return id
end

function add!(f::Formulation, var::Variable, id::Id{VarState}, 
        membership::Membership{ConstrState})
    set!(f.vars, id, var)
    add_variable!(f.memberships, id, membership)
    return id
end

function add!(f::Formulation, constr::Constraint, id::Id{ConstrState})
    set!(f.constrs, id, constr)
    add_constraint!(f.memberships, id)
    return id
end

function add!(f::Formulation, constr::Constraint, id::Id{ConstrState},
       membership::Membership{VarState})
    set!(f.constrs, id, constr)
    add_constraint!(f.memberships, id, membership)
    return id
end

function add!(f::Formulation, var::Variable, Duty::Type{<: AbstractVarDuty})
    uid = getnewuid(f.problem.var_counter)
    id = Id(uid, VarState(Duty, var))
    add!(f, var, id)
    return id
end

function add!(f::Formulation, var::Variable, Duty::Type{<: AbstractVarDuty}, 
        membership::Membership{ConstrState})
    uid = getnewuid(f.problem.var_counter)
    id = Id(uid, VarState(Duty, var))
    add!(f, var, id, membership)
    return id
end

function add!(f::Formulation, constr::Constraint, 
        Duty::Type{<: AbstractConstrDuty})
    uid = getnewuid(f.problem.constr_counter)
    id = Id(uid, ConstrState(Duty, constr))
    add!(f, constr, id)
    return id
end

function add!(f::Formulation, constr::Constraint, 
        Duty::Type{<: AbstractConstrDuty}, membership::Membership{VarState})
    uid = getnewuid(f.problem.constr_counter)
    id = Id(uid, ConstrState(Duty, constr))
    add!(f, constr, id, membership)
    return id
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
        primal_sol = retrieve_primal_sol(form, filter(_explicit_ , form.vars))
        push!(primal_sols, primal_sol)
        dual_sol = retrieve_dual_sol(form, filter(_active_ , form.constrs))
        if update_form
            form.primal_solution_record = primal_sol
            if dual_sol != nothing
                dual_solution_record = dual_sol
            end
        end
        return (status, primal_sol.value, primal_sols, dual_sol)
    end
    @logmsg LogLevel(-4) string("Solver has no result to show.")
    return (status, Inf, nothing, nothing)
end

function compute_original_cost(sol::PrimalSolution, form::Formulation)
    cost = 0.0
    for (var_uid, val) in sol.members
        var = getvar(form, var_uid)
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
    constrinfo = getinfo(id)
    print(io, id, " ", getname(constr), " : ")
    membership = get_var_members_of_constr(f, id)
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
    d = getduty(constrinfo)
    println(io, " (", d ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    for id in sort!(getconstr_ids(f))
        _show_constraint(io, f, id)
    end
    return
end

function _show_variable(io::IO, f::Formulation, id)
    var = getvar(f, id)
    varinfo = getinfo(id)
    name = getname(var)
    lb = getlb(varinfo)
    ub = getub(varinfo)
    t = getkind(var)
    d = getduty(varinfo)
    f = getflag(var)
    println(io, id, " ", lb, " <= ", name, " <= ", ub, " (", t, " | ", d ," | ", f , ")")
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

function load_problem_in_optimizer(formulation::Formulation)
    println("Loading formulation ", formulation.uid)
    for (id, var) in filter(_explicit_, getvars(formulation))
        add_variable_in_optimizer(formulation.moi_optimizer, id)
    end
    for (id, constr) in filter(_active_, getconstrs(formulation))
        @show get_var_members_of_constr(formulation, id)
        @show filter(_explicit_, get_var_members_of_constr(formulation, id))
        add_constraint_in_optimizer(
            formulation.moi_optimizer, id,
            filter(_explicit_, get_var_members_of_constr(formulation, id))
        )
    end
end

function initialize_moi_optimizer(form::Formulation, factory::JuMP.OptimizerFactory)
    form.moi_optimizer = create_moi_optimizer(factory)
end

function retrieve_primal_sol(form::Formulation,
                             vars::Manager{Id{VarState}, Variable})
    new_sol = Membership(Variable)
    new_obj_val = MOI.get(form.moi_optimizer, MOI.ObjectiveValue())
    #error("Following line does not work.")
    fill_primal_sol(form.moi_optimizer, new_sol, vars)
    primal_sol = PrimalSolution(new_obj_val, new_sol)
    @logmsg LogLevel(-4) string("Objective value: ", new_obj_val)
    return primal_sol
end

function retrieve_dual_sol(form::Formulation,
                           constrs::Manager{Id{ConstrState}, Constraint})
    # TODO check if supported by solver
    if MOI.get(form.moi_optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
        return nothing
    end
    new_sol = Membership(Constraint)
    problem.obj_bound = MOI.get(optimizer, MOI.ObjectiveBound())
    fill_dual_sol(form.moi_optimizer, new_sol, constrs)
    dual_sol = DualSolution(-Inf, new_sol)
    return dual_sol
end

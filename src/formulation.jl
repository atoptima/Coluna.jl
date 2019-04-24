mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::Int
    var_counter::Counter
    constr_counter::Counter
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master

    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    manager::FormulationManager
    obj_sense::Type{<:AbstractObjSense}

    # solver_info::Any
    callback
end

function Formulation{D}(form_counter::Counter;
                        parent_formulation = nothing,
                        obj_sense::Type{<:AbstractObjSense} = MinSense,
                        moi_optimizer::Union{MOI.AbstractOptimizer,
                                             Nothing} = nothing
                        ) where {D<:AbstractFormDuty,S<:AbstractObjSense}
    return Formulation{D}(
        getnewuid(form_counter), Counter(), Counter(),
        parent_formulation, moi_optimizer, FormulationManager(),
        obj_sense, nothing
    )
end

haskey(f::Formulation, id::Id) = haskey(f.manager, id)

getvar(f::Formulation, id::VarId) = getvar(f.manager, id) 

getvarcounter(f::Formulation) = f.var_counter.value

get_constr(f::Formulation, id::ConstrId) = get_constr(f.manager, id)

get_vars(f::Formulation) = get_vars(f.manager)

get_constrs(f::Formulation) = get_constrs(f.manager)

get_coefficient_matrix(f::Formulation) = get_coefficient_matrix(f.manager)

get_uid(f::Formulation) = f.uid

getobjsense(f::Formulation) = f.obj_sense

get_optimizer(f::Formulation) = f.moi_optimizer

function generatevarid(f::Formulation)
    return VarId(getnewuid(f.var_counter), f.uid)
end

function generateconstrid(f::Formulation)
    return ConstrId(getnewuid(f.constr_counter), f.uid)
end

function set_var!(f::Formulation,
                  name::String,
                  duty::Type{<:AbstractVarDuty};
                  cost::Float64 = 0.0,
                  lb::Float64 = 0.0,
                  ub::Float64 = Inf,
                  kind::VarKind = Continuous,
                  sense::VarSense = Positive,
                  inc_val::Float64 = 0.0,
                  is_active::Bool = true,
                  is_explicit::Bool = true,
                  moi_index::MoiVarIndex = MoiVarIndex())
    id = generatevarid(f)
    v_data = VarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    return add_var!(f, v)
end

add_var!(f::Formulation, var::Variable) = add_var!(f.manager, var)

function clone_var!(dest::Formulation, src::Formulation, var::Variable)
    add_var!(dest, var)
    return clone_var!(dest.manager, src.manager, var)
end

function set_constr!(f::Formulation,
                     name::String,
                     duty::Type{<:AbstractConstrDuty};
                     rhs::Float64 = 0.0,
                     kind::ConstrKind = 0.0,
                     sense::ConstrSense = 0.0,
                     inc_val::Float64 = 0.0,
                     is_active::Bool = true,
                     is_explicit::Bool = true,
                     moi_index::MoiConstrIndex = MoiConstrIndex())
    id = generateconstrid(f)
    c_data = ConstrData(rhs, kind, sense,  inc_val, is_active, is_explicit)
    c = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)
    return add_constr!(f, c)
end

add_constr!(f::Formulation, constr::Constraint) = add_constr!(f.manager, constr)

function clone_constr!(dest::Formulation, src::Formulation, constr::Constraint)
    add_constr!(dest, constr)
    return clone_constr!(dest.manager, src.manager, constr)
end

function register_objective_sense!(f::Formulation, min::Bool)
    if min
        f.obj_sense = MinSense
    else
        f.obj_sense = MaxSense
    end
    return
end

# function optimize!(f::Formulation)
#     setup_solver(f.moi_optimizer, f, solver_info)
#     res = optimize!(f, f.moi_optimizer, true)
#     setdown_solver(f.moi_optimizer, f, solver_info)
#     return res
# end

function optimize!(form::Formulation, optimizer = form.moi_optimizer)
    call_moi_optimize_with_silence(form.moi_optimizer)
    status = MOI.get(form.moi_optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)
    if MOI.get(optimizer, MOI.ResultCount()) >= 1
        primal_sols = retrieve_primal_sols(
            form, filter(_explicit_ , get_vars(form))
        )
        dual_sol = retrieve_dual_sol(form, filter(_explicit_ , get_constrs(form)))
        return (status, primal_sols[1].bound, primal_sols, dual_sol)
    end
    @warn "Solver has no result to show."
    return (status, Inf, nothing, nothing)
end

function load_problem_in_optimizer(formulation::Formulation)
    optimizer = get_optimizer(formulation)
    for (id, var) in filter(_explicit_, get_vars(formulation))
        add_variable_in_optimizer(optimizer, var)
    end
    constrs = filter(
        _explicit_, rows(get_coefficient_matrix(formulation))
    )
    for (constr_id, members) in constrs
        add_constraint_in_optimizer(
            optimizer, getelements(constrs)[constr_id],
            filter(_explicit_, members)
        )
    end
    _show_optimizer(get_optimizer(formulation))
    return
end

function initialize_moi_optimizer(form::Formulation, factory::JuMP.OptimizerFactory)
    form.moi_optimizer = create_moi_optimizer(factory, form.obj_sense)
end

function retrieve_primal_sols(form::Formulation, vars::VarDict)
    ObjSense = getobjsense(form)
    primal_sols = PrimalSolution{ObjSense}[]
    for res_idx in 1:MOI.get(get_optimizer(form), MOI.ResultCount())
        new_sol = Dict{VarId,Float64}()
        new_obj_val = MOI.get(form.moi_optimizer, MOI.ObjectiveValue())
        fill_primal_sol(form.moi_optimizer, new_sol, vars, res_idx)
        primal_sol = PrimalSolution(ObjSense, new_obj_val, new_sol)
        push!(primal_sols, primal_sol)
    end
    return primal_sols
end

function retrieve_dual_sol(form::Formulation,
                           constrs::ConstrDict)
    # TODO check if supported by solver
    if MOI.get(form.moi_optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
        # println("dual status is : ", MOI.get(form.moi_optimizer, MOI.DualStatus()))
        return nothing
    end
    new_sol = Dict{ConstrId,Float64}()
    obj_bound = MOI.get(form.moi_optimizer, MOI.ObjectiveBound())
    fill_dual_sol(form.moi_optimizer, new_sol, constrs)
    dual_sol = DualSolution{form.obj_sense}(obj_bound, new_sol)
    return dual_sol
end

# function is_sol_integer(sol::PrimalSolution, tolerance::Float64)
#     for (var_id, var_val) in sol.members
#         if (!is_value_integer(var_val, tolerance)
#                 && (get_kind(getstate(var_id)) == 'I' || get_kind(getstate(var_id)) == 'B'))
#             @logmsg LogLevel(-2) "Sol is fractional."
#             return false
#         end
#     end
#     @logmsg LogLevel(-4) "Solution is integer!"
#     return true
# end


# function update_var_status(var_id::Id{VarState},
#                            new_status::Status)
#     @logmsg LogLevel(-2) "change var status "  getstatus(getstate(var_id)) == new_status var_id

#     setstatus!(getstate(var_id), new_status)
# end

# function update_constr_status(constr_id::Id{ConstrState},
#                               new_status::Status)
#     @logmsg LogLevel(-2) "change var status "  getstatus(getstate(constr_id)) == new_status constr_id

#     setstatus!(getstate(constr_id), new_status)
# end

function _show_obj_fun(io::IO, f::Formulation)
    print(io, getobjsense(f), " ")
    vars = filter(_explicit_, get_vars(f))
    ids = sort!(collect(keys(vars)), by = getsortid)
    for id in ids
        name = get_name(vars[id])
        cost = get_cost(get_cur_data(vars[id]))
        op = (cost < 0.0) ? "-" : "+" 
        print(io, op, " ", abs(cost), " ", name, " ")
    end
    println(io, " ")
    return
end

function _show_constraint(io::IO, f::Formulation, constr_id::ConstrId,
                          members::VarMembership)
    constr = get_constr(f, constr_id)
    constr_data = get_cur_data(constr)
    print(io, get_name(constr), " : ")
    ids = sort!(collect(keys(members)), by = getsortid)
    for id in ids
        coeff = members[id]
        var = getvar(f, id)
        name = get_name(var)
        op = (coeff < 0.0) ? "-" : "+"
        print(io, op, " ", abs(coeff), " ", name, " ")
    end
    if get_sense(constr_data) == Equal
        op = "=="
    elseif get_sense(constr_data) == Greater
        op = ">="
    else
        op = "<="
    end
    print(io, " ", op, " ", get_rhs(constr_data))
    println(io, " (", get_duty(constr), " | ", is_explicit(constr_data) ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    # constrs = filter(
    #     _explicit_, rows(get_coefficient_matrix(f))
    # )
    constrs = rows(get_coefficient_matrix(f))
    ids = sort!(collect(keys(constrs)), by = getsortid)
    for id in ids
        _show_constraint(io, f, id, constrs[id])
    end
    return
end

function _show_variable(io::IO, f::Formulation, var::Variable)
    var_data = get_cur_data(var)
    name = get_name(var)
    lb = get_lb(var_data)
    ub = get_ub(var_data)
    t = get_kind(var_data)
    d = get_duty(var)
    e = is_explicit(var_data)
    println(io, lb, " <= ", name, " <= ", ub, " (", t, " | ", d , " | ", e, ")")
end

function _show_variables(io::IO, f::Formulation)
    # vars = filter(_explicit_, get_vars(f))
    vars = get_vars(f)
    ids = sort!(collect(keys(vars)), by = getsortid)
    for id in ids
        _show_variable(io, f, vars[id])
    end
end

function Base.show(io::IO, f::Formulation)
    println(io, "Formulation id = ", get_uid(f))
    _show_obj_fun(io, f)
    _show_constraints(io, f)
    _show_variables(io, f)
    return
end

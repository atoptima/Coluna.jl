mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::Int
    var_counter::Counter
    constr_counter::Counter
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master

    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    manager::FormulationManager
    obj_sense::Type{<:AbstractObjSense}

    # Do we still need to store solutions in formulation
    # Before it was mainly used for partial solutions, but now partial solutions are sotred in manager
    primal_inc_bound::Float64
    dual_inc_bound::Float64
    primal_solution_record::Union{PrimalSolution, Nothing}
    dual_solution_record::Union{DualSolution, Nothing}
    ###

    # solver_info::Any

    callback
end

function Formulation{D}(form_counter::Counter;
                        parent_formulation = nothing,
                        obj_sense::Type{<:AbstractObjSense} = MinSense,
                        moi_optimizer::Union{MOI.AbstractOptimizer,
                                             Nothing} = nothing,
                        primal_inc_bound::Float64 = Inf,
                        dual_inc_bound::Float64 = -Inf
                        ) where {D<:AbstractFormDuty,S<:AbstractObjSense}
    return Formulation{D}(
        getnewuid(form_counter), Counter(), Counter(),
        parent_formulation, moi_optimizer, FormulationManager(),
        obj_sense, primal_inc_bound, dual_inc_bound, nothing,
        nothing, nothing
    )
end


haskey(f::Formulation, id::Id) = haskey(f.manager, id)

getvar(f::Formulation, id::VarId) = getvar(f.manager, id)

get_constr(f::Formulation, id::ConstrId) = get_constr(f.manager, id)

getvars(f::Formulation) = getvars(f.manager)

get_constrs(f::Formulation) = get_constrs(f.manager)

get_coefficient_matrix(f::Formulation) = get_coefficient_matrix(f.manager)

getuid(f::Formulation) = f.uid

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
                  moi_index::MoiVarIndex = MoiVarIndex())
    id = generatevarid(f)
    v_data = VarData(cost, lb, ub, kind, sense, true, true)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    return add_var!(f, v)
end

add_var!(f::Formulation, var::Variable) = add_var!(f.manager, var)

function clone_var!(dest::Formulation, src::Formulation, var::Variable)
    add_var!(dest, var)
    clone_var!(dest.manager, src.manager, var)
end

function set_constr!(f::Formulation,
                     name::String,
                     duty::Type{<:AbstractConstrDuty};
                     rhs::Float64 = 0.0,
                     kind::ConstrKind = 0.0,
                     sense::ConstrSense = 0.0,
                     moi_index::MoiConstrIndex = MoiConstrIndex())
    id = generateconstrid(f)
    c_data = ConstrData(rhs, kind, sense, true, true)
    c = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)
    return add_constr!(f, c)
end

add_constr!(f::Formulation, constr::Constraint) = add_constr!(f.manager, constr)

function clone_constr!(dest::Formulation, src::Formulation, constr::Constraint)
    add_constr!(dest, constr)
    clone_constr!(dest.manager, src.manager, constr)
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

function optimize!(form::Formulation, optimizer = form.moi_optimizer,
                  update_form = true)
    call_moi_optimize_with_silence(form.moi_optimizer)
    status = MOI.get(form.moi_optimizer, MOI.TerminationStatus())
    primal_sols = PrimalSolution{form.obj_sense}[]
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)
    if MOI.get(optimizer, MOI.ResultCount()) >= 1
        primal_sol = retrieve_primal_sol(form, filter(_explicit_ , getvars(form)))
        push!(primal_sols, primal_sol)
        dual_sol = retrieve_dual_sol(form, filter(_explicit_ , get_constrs(form)))
        if update_form
            form.primal_solution_record = primal_sol
            if dual_sol != nothing
                form.dual_solution_record = dual_sol
            end
        end
        return (status, primal_sol.bound, primal_sols, dual_sol)
    end
    @logmsg LogLevel(-4) string("Solver has no result to show.")
    return (status, Inf, nothing, nothing)
end

function load_problem_in_optimizer(formulation::Formulation)
    optimizer = get_optimizer(formulation)
    for (id, var) in filter(_explicit_, getvars(formulation))
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
   @show get_optimizer(formulation)
end

function initialize_moi_optimizer(form::Formulation, factory::JuMP.OptimizerFactory)
    form.moi_optimizer = create_moi_optimizer(factory)
end

function retrieve_primal_sol(form::Formulation,
                             vars::VarDict)
    new_sol = Dict{VarId,Float64}()
    new_obj_val = MOI.get(form.moi_optimizer, MOI.ObjectiveValue())
    #error("Following line does not work.")
    fill_primal_sol(form.moi_optimizer, new_sol, vars)
    primal_sol = PrimalSolution{form.obj_sense}(new_obj_val, new_sol)
    @logmsg LogLevel(-4) string("Objective value: ", new_obj_val)
    return primal_sol
end

function retrieve_dual_sol(form::Formulation,
                           constrs::ConstrDict)
    # TODO check if supported by solver
    if MOI.get(form.moi_optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
        println("dual status is : ", MOI.get(form.moi_optimizer, MOI.DualStatus()))
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
#                 && (getkind(getstate(var_id)) == 'I' || getkind(getstate(var_id)) == 'B'))
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
    for (id, var) in filter(_explicit_, getvars(f))
        name = getname(var)
        cost = getcost(get_cur_data(var))
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
    print(io, constr_id, " ", getname(constr), " : ")
    for (var_id, coeff) in members
        var = getvar(f, var_id)
        name = getname(var)
        op = (coeff < 0.0) ? "-" : "+"
        print(io, op, " ", abs(coeff), " ", name, " ")
    end
    if getsense(constr_data) == Equal
        op = "=="
    elseif getsense(constr_data) == Greater
        op = ">="
    else
        op = "<="
    end
    print(io, " ", op, " ", getrhs(constr_data))
    println(io, " (", getduty(constr), " ", is_explicit(constr_data) ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    constrs = filter(
        _explicit_, rows(get_coefficient_matrix(f))
    )
    for (constr_id, members) in constrs
        _show_constraint(io, f, constr_id, members)
    end
    return
end

function _show_variable(io::IO, f::Formulation, var::Variable)
    var_data = get_cur_data(var)
    name = getname(var)
    lb = getlb(var_data)
    ub = getub(var_data)
    t = getkind(var_data)
    d = getduty(var)
    e = is_explicit(var_data)
    println(io, getid(var), " ", lb, " <= ", name, " <= ", ub, " (", t, " | ", d , " | ", e, ")")
end

function _show_variables(io::IO, f::Formulation)
    for (id, var) in filter(_explicit_, getvars(f))
        _show_variable(io, f, var)
    end
end

function Base.show(io::IO, f::Formulation)
    println(io, "Formulation id = ", getuid(f))
    _show_obj_fun(io, f)
    _show_constraints(io, f)
    _show_variables(io, f)
    return
end

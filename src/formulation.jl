"""
    VarConstrCache{T<:AbstractVarConstr}

A `VarConstrCache{T}` stores the ids of the entities to be added and removed from the formulation where it belongs.
"""
mutable struct VarConstrCache{T<:AbstractVarConstr}
    added::Set{Id{T}}
    removed::Set{Id{T}}
end

"""
    VarConstrCache{T}() where {T<:AbstractVarConstr}

Constructs an empty `VarConstrCache{T}` for entities of type `T`.
"""
VarConstrCache{T}() where {T<:AbstractVarConstr} = VarConstrCache{T}(Set{T}(), Set{T}())

function add_vc!(vc_cache::VarConstrCache, vc::AbstractVarConstr)
    !get_cur_is_explicit(vc) && return
    id = getid(vc)
    id in vc_cache.removed && delete!(vc_cache.removed, id)
    push!(vc_cache.added, id)
    return
end

function remove_vc!(vc_cache::VarConstrCache, vc::AbstractVarConstr)
    !get_cur_is_explicit(vc) && return
    id = getid(vc)
    id in vc_cache.added && delete!(vc_cache.added, id)
    push!(vc_cache.removed, id)
    return
end

"""
    FormulationCache()

A `FormulationCache` stores all changes done to a `Formulation` `f` since last call to `optimize!(f)`.
When function `optimize!(f)` is called, the moi_optimizer is synched with all changes in FormulationCache.

When `f` is modified, such modification should not be passed directly to its optimizer, but instead should be passed to `f.cache`.

The concerned modificatios are:
1. Cost change in a variable
2. Bound change in a variable
3. Right-hand side change in a Constraint
4. Variable is removed
5. Variable is added
6. Constraint is removed
7. Constraint is added
8. Coefficient in the matrix is modified (reset)
"""
mutable struct FormulationCache
    changed_cost::Set{Id{Variable}}
    changed_bound::Set{Id{Variable}}
    changed_rhs::Set{Id{Constraint}}
    var_cache::VarConstrCache{Variable}
    constr_cache::VarConstrCache{Constraint}
    reset_coeffs::Dict{Pair{Id{Constraint},Id{Variable}},Float64}
    #reset_partial_sols::Dict{Pair{Id{Variable},Id{Variable}},Float64}
end
"""
    FormulationCache()

Constructs an empty `FormulationCache`.
"""
FormulationCache() = FormulationCache(
    Set{Id{Variable}}(), Set{Id{Variable}}(), Set{Id{Constraint}}(),
    VarConstrCache{Variable}(), VarConstrCache{Constraint}(),
    Dict{Pair{Id{Constraint},Id{Variable}},Float64}()
    # , Dict{Pair{Id{Variable},Id{Variable}},Float64}()
)

function undo_modifs!(cache::FormulationCache, v::Variable)
    id = getid(v)
    delete!(cache.changed_cost, id)
    delete!(cache.changed_bound, id)
    return
end

function undo_modifs!(cache::FormulationCache, c::Constraint)
    id = getid(c)
    delete!(cache.changed_rhs, id)
    return
end

function change_cost!(cache::FormulationCache, v::Variable)
    !get_cur_is_explicit(v) && return
    push!(cache.changed_cost, getid(v))
    return
end

function change_bound!(cache::FormulationCache, v::Variable)
    !get_cur_is_explicit(v) && return
    push!(cache.changed_bound, getid(v))
    return
end

"""
    Formulation{Duty<:AbstractFormDuty}

Representation of a formulation which is typically solved by either a MILP or a dynamic program solver.

Such solver must be interfaced with MOI and its pointer is stored in the field `moi_optimizer`.
"""
mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::Int
    var_counter::Counter
    constr_counter::Counter
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master

    moi_optimizer::Union{MOI.AbstractOptimizer, Nothing}
    manager::FormulationManager
    obj_sense::Type{<:AbstractObjSense}

    cache::FormulationCache
    solver_info::Any
    callback
end

"""
    Formulation{D}(form_counter::Counter,
                   parent_formulation = nothing,
                   obj_sense::Type{<:AbstractObjSense} = MinSense,
                   moi_optimizer::Union{MOI.AbstractOptimizer,
                                        Nothing} = nothing
                   ) where {D<:AbstractFormDuty}

Constructs a `Formulation` of duty `D` for which the objective sense is `obj_sense`.
"""
function Formulation{D}(form_counter::Counter;
                        parent_formulation = nothing,
                        obj_sense::Type{<:AbstractObjSense} = MinSense,
                        moi_optimizer::Union{MOI.AbstractOptimizer,
                                             Nothing} = nothing
                        ) where {D<:AbstractFormDuty}
    return Formulation{D}(
        getnewuid(form_counter), Counter(), Counter(),
        parent_formulation, moi_optimizer, FormulationManager(),
        obj_sense, FormulationCache(), nothing, nothing
    )
end

"Returns true iff a `Variable` of `Id` `id` was already added to `Formulation` `f`."
haskey(f::Formulation, id::Id) = haskey(f.manager, id)

"Returns the `Variable` whose `Id` is `id` if such variable is in `Formulation` `f`."
getvar(f::Formulation, id::VarId) = getvar(f.manager, id) 

"Returns the value of the variable counter of `Formulation` `f`."
getvarcounter(f::Formulation) = f.var_counter.value

"Returns the `Constraint` whose `Id` is `id` if such constraint is in `Formulation` `f`."
getconstr(f::Formulation, id::ConstrId) = getconstr(f.manager, id)

"Returns all the variables in `Formulation` `f`."
getvars(f::Formulation) = getvars(f.manager)

"Returns all the constraints in `Formulation` `f`."
getconstrs(f::Formulation) = getconstrs(f.manager)

"Returns the representation of the coefficient matrix stored in the formulation manager."
getcoefmatrix(f::Formulation) = getcoefmatrix(f.manager)
getpartialsolmatrix(f::Formulation) = getpartialsolmatrix(f.manager)

"Returns the `uid` of `Formulation` `f`."
getuid(f::Formulation) = f.uid

"Returns the objective function sense of `Formulation` `f`."
getobjsense(f::Formulation) = f.obj_sense

"Returns the `MOI.Optimizer` of `Formulation` `f`."
get_optimizer(f::Formulation) = f.moi_optimizer

function generatevarid(f::Formulation)
    return VarId(getnewuid(f.var_counter), f.uid)
end

function generateconstrid(f::Formulation)
    return ConstrId(getnewuid(f.constr_counter), f.uid)
end

reset_cache!(f::Formulation) = f.cache = FormulationCache()

"""
    commit_cost_change!(f::Formulation, v::Variable)

Passes the cost modification of variable `v` to the underlying MOI solver `f.moi_solver`.

Should be called if a cost modificatiom to a variable is definitive and should be transmitted to the underlying MOI solver.
"""
commit_cost_change!(f::Formulation, v::Variable) = change_cost!(f.cache, v)

"""
    commit_bound_change!(f::Formulation, v::Variable)

Passes the bound modification of variable `v` to the underlying MOI solver `f.moi_solver`.

Should be called if a bound modificatiom to a variable is definitive and should be transmitted to the underlying MOI solver.
"""
commit_bound_change!(f::Formulation, v::Variable) = change_bound!(f.cache, v)

"""
    commit_coef_matrix_change!(f::Formulation, c_id::Id{Constraint}, v_id::Id{Variable}, coeff::Float64)

Sets the coefficient `coeff` in the (`c_id`, `v_id`) cell of the matrix.

Should be called if a coefficient modification in the matrix is definitive and should be transmitted to the underlying MOI solver.
"""
function commit_coef_matrix_change!(f::Formulation, c_id::Id{Constraint},
                               v_id::Id{Variable}, coeff::Float64)
    f.cache.reset_coeffs[Pair(c_id,v_id)] = coeff
end
#function commit_partialsol_matrix_change!(f::Formulation,
#                                          v_id::Id{Variable},
#                                          ps_id::Id{Variable},
#                                          coeff::Float64)
#    f.cache.reset_partial_sols[Pair(v_id,ps_id)] = coeff
#end

"Creates a `Variable` according to the parameters passed and adds it to `Formulation` `f`."
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

"Adds `Variable` `var` to `Formulation` `f`."
function add_var!(f::Formulation, var::Variable)
    add_vc!(f.cache.var_cache, var)
    return add_var!(f.manager, var)
end

function add_partialsol!(f::Formulation, var::Variable)
    return add_partialsol!(f.manager, var)
end

function clone_var!(dest::Formulation, src::Formulation, var::Variable)
    add_var!(dest, var)
    return clone_var!(dest.manager, src.manager, var)
end

"Creates a `Constraint` according to the parameters passed and adds it to `Formulation` `f`."
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

"Adds `Constraint` `constr` to `Formulation` `f`."
function add_constr!(f::Formulation, constr::Constraint)
    add_vc!(f.cache.constr_cache, constr)
    return add_constr!(f.manager, constr)
end

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

function sync_solver(f::Formulation)
    # println("Synching formulation ", getuid(f))
    optimizer = get_optimizer(f)
    cache = f.cache
    matrix = getcoefmatrix(f)
    # Remove constrs
    for id in cache.constr_cache.removed
        @warn "Should not remove constraints yet"
        c = getconstr(f, id)
        # println("Removing constraint ", getname(c))
        undo_modifs!(cache, c)
        remove_from_optimizer!(optimizer, c)
    end
    # Remove vars
    for id in cache.var_cache.removed
        @warn "Should not remove variables yet"
        v = getvar(f, id)
        # println("Removing variable ", getname(v))
        undo_modifs!(cache, v)
        remove_from_optimizer!(optimizer, v)
    end
    # Add vars
    for id in cache.var_cache.added
        v = getvar(f, id)
        # println("Adding variable ", getname(v))
        undo_modifs!(cache, v)
        add_to_optimzer!(optimizer, v)
    end
    # Add constrs
    for id in cache.constr_cache.added
        c = getconstr(f, id)
        # println("Adding constraint ", getname(c))
        undo_modifs!(cache, c)
        add_to_optimzer!(optimizer, c, filter(_explicit_, matrix[id,:]))
    end
    # Update variable costs
    for id in cache.changed_cost
        update_cost_in_optimizer(optimizer, getvar(f, id))
    end
    # Update variable bounds
    for id in cache.changed_bound
        @warn "Update of variable bounds not yet implemented"
    end
    # Update constraint rhs
    for id in cache.changed_rhs
        @warn "Update of constraint rhs not yet implemented"
    end
    # Update matrix
    for ((c_id, v_id), coeff) in cache.reset_coeffs
        c = getconstr(f, c_id)
        v = getvar(f, v_id)
        # println("Setting matrix coefficient: (", getname(c), ",", getname(v), ") = ", coeff)
        update_constr_member_in_optimizer(optimizer, c, v, coeff)
    end
    reset_cache!(f)
    return
end

"Calls optimization routine for `Formulation` `f`."
function optimize!(form::Formulation)
    # println("Before sync")
    # _show_optimizer(form.moi_optimizer)
    sync_solver(form)
    # println("After sync")
    # _show_optimizer(form.moi_optimizer)

#     setup_solver(f.moi_optimizer, f, solver_info)

    call_moi_optimize_with_silence(form.moi_optimizer)
    status = MOI.get(form.moi_optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(-4) string("Optimization finished with status: ", status)
    if MOI.get(form.moi_optimizer, MOI.ResultCount()) >= 1
        primal_sols = retrieve_primal_sols(
            form, filter(_explicit_ , getvars(form))
        )
        dual_sol = retrieve_dual_sol(form, filter(_explicit_ , getconstrs(form)))
        return (status, primal_sols[1].bound, primal_sols, dual_sol)
    end
    @warn "Solver has no result to show."
#     setdown_solver(f.moi_optimizer, f, solver_info)
    return (status, Inf, nothing, nothing)
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

function retrieve_dual_sol(form::Formulation, constrs::ConstrDict)
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
    vars = filter(_explicit_, getvars(f))
    ids = sort!(collect(keys(vars)), by = getsortid)
    for id in ids
        name = getname(vars[id])
        cost = get_cost(getcurdata(vars[id]))
        op = (cost < 0.0) ? "-" : "+" 
        print(io, op, " ", abs(cost), " ", name, " ")
    end
    println(io, " ")
    return
end

function _show_constraint(io::IO, f::Formulation, constr_id::ConstrId,
                          members::VarMembership)
    constr = getconstr(f, constr_id)
    constr_data = getcurdata(constr)
    print(io, getname(constr), " : ")
    ids = sort!(collect(keys(members)), by = getsortid)
    for id in ids
        coeff = members[id]
        var = getvar(f, id)
        name = getname(var)
        op = (coeff < 0.0) ? "-" : "+"
        print(io, op, " ", abs(coeff), " ", name, " ")
    end
    if setsense(constr_data) == Equal
        op = "=="
    elseif setsense(constr_data) == Greater
        op = ">="
    else
        op = "<="
    end
    print(io, " ", op, " ", getrhs(constr_data))
    println(io, " (", getduty(constr), " | ", is_explicit(constr_data) ,")")
    return
end

function _show_constraints(io::IO , f::Formulation)
    # constrs = filter(
    #     _explicit_, rows(getcoefmatrix(f))
    # )
    constrs = rows(getcoefmatrix(f))
    ids = sort!(collect(keys(constrs)), by = getsortid)
    for id in ids
        _show_constraint(io, f, id, constrs[id])
    end
    return
end

function _show_variable(io::IO, f::Formulation, var::Variable)
    var_data = getcurdata(var)
    name = getname(var)
    lb = getlb(var_data)
    ub = getub(var_data)
    t = getkind(var_data)
    d = getduty(var)
    e = is_explicit(var_data)
    println(io, lb, " <= ", name, " <= ", ub, " (", t, " | ", d , " | ", e, ")")
end

function _show_variables(io::IO, f::Formulation)
    # vars = filter(_explicit_, getvars(f))
    vars = getvars(f)
    ids = sort!(collect(keys(vars)), by = getsortid)
    for id in ids
        _show_variable(io, f, vars[id])
    end
end

function Base.show(io::IO, f::Formulation)
    println(io, "Formulation id = ", getuid(f))
    _show_obj_fun(io, f)
    _show_constraints(io, f)
    _show_variables(io, f)
    return
end

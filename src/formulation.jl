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

    buffer::FormulationBuffer
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
        obj_sense, FormulationBuffer(), nothing, nothing
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

getexpressionmatrix(f::Formulation) = getexpressionmatrix(f.manager)

getprimalspsolmatrix(f::Formulation) = getprimalspsolmatrix(f.manager)

gedualspsolmatrix(f::Formulation) = getdualspsolmatrix(f.manager)

"Returns the `uid` of `Formulation` `f`."
getuid(f::Formulation) = f.uid

"Returns the objective function sense of `Formulation` `f`."
getobjsense(f::Formulation) = f.obj_sense

"Returns the `MOI.Optimizer` of `Formulation` `f`."
get_optimizer(f::Formulation) = f.moi_optimizer

getelem(f::Formulation, id::VarId) = getvar(f, id)
getelem(f::Formulation, id::ConstrId) = getconstr(f, id)

generatevarid(f::Formulation) = VarId(getnewuid(f.var_counter), f.uid)
generateconstrid(f::Formulation) = ConstrId(getnewuid(f.constr_counter), f.uid)

_reset_buffer!(f::Formulation) = f.buffer = FormulationBuffer()

"""
    setcost!(f::Formulation, v::Variable, new_cost::Float64)

Sets `v.cur_data.cost` as well as the cost of `v` in `f.moi_optimizer` to be 
euqal to `new_cost`. Change on `f.moi_optimizer` will be buffered.
"""
function setcost!(f::Formulation, v::Variable, new_cost::Float64)
    setcurcost!(v, new_cost)
    change_cost!(f.buffer, v)
end

"""
    setub!(f::Formulation, v::Variable, new_ub::Float64)

Sets `v.cur_data.ub` as well as the bounds constraint of `v` in `f.moi_optimizer`
according to `new_ub`. Change on `f.moi_optimizer` will be buffered.
"""
function setub!(f::Formulation, v::Variable, new_ub::Float64)
    setcurub!(v, new_ub)
    change_bound!(f.buffer, v)
end

"""
    setlb!(f::Formulation, v::Variable, new_lb::Float64)

Sets `v.cur_data.lb` as well as the bounds constraint of `v` in `f.moi_optimizer` 
according to `new_lb`. Change on `f.moi_optimizer` will be buffered.
"""
function setlb!(f::Formulation, v::Variable, new_lb::Float64)
    setcurlb!(v, new_lb)
    change_bound!(f.buffer, v)
end

"""
    setkind!(f::Formulation, v::Variable, new_kind::VarKind)

Sets `v.cur_data.kind` as well as the kind constraint of `v` in `f.moi_optimizer` 
according to `new_kind`. Change on `f.moi_optimizer` will be buffered.
"""
function setkind!(f::Formulation, v::Variable, new_kind::VarKind)
    setcurkind(v, new_kind)
    change_kind!(f.buffer, v)
end

"""
    set_matrix_coeff!(f::Formulation, v_id::Id{Variable}, c_id::Id{Constraint}, new_coeff::Float64)

Buffers the matrix modification in `f.buffer` to be sent to `f.moi_optimizer` right before next call to optimize!.
"""
set_matrix_coeff!(
    f::Formulation, v_id::Id{Variable}, c_id::Id{Constraint}, new_coeff::Float64
) = set_matrix_coeff!(f.buffer, v_id, c_id, new_coeff)

"Creates a `Variable` according to the parameters passed and adds it to `Formulation` `f`."
function setvar!(f::Formulation,
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
                  moi_index::MoiVarIndex = MoiVarIndex(),
                  members::Union{ConstrMembership,Nothing} = nothing)
    id = generatevarid(f)
    v_data = VarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    members != nothing && setmembers!(f, v, members)
    return addvar!(f, v)
end

function setprimalspsol!(f::Formulation,
                         name::String,
                         sol::PrimalSolution{S},
                         duty::Type{<:AbstractVarDuty};
                         lb::Float64 = 0.0,
                         ub::Float64 = Inf,
                         kind::VarKind = Continuous,
                         sense::VarSense = Positive,
                         inc_val::Float64 = 0.0,
                         is_active::Bool = true,
                         is_explicit::Bool = true,
                         moi_index::MoiVarIndex = MoiVarIndex()) where {S}
    primal_sp_sol_id = generatevarid(f)
    primal_sp_sol_data = VarData(getvalue(sol), lb, ub, kind, sense, inc_val, is_active, is_explicit)
    primal_sp_sol_var = Variable(primal_sp_sol_id, name, duty; var_data = primal_sp_sol_data, moi_index = moi_index)

    coef_matrix = getcoefmatrix(f)
    primal_sp_sol_matrix = getprimalspsolmatrix(f)

    addvar!(f, primal_sp_sol_var)
    
    for (var_id, var_val) in sol
        primal_sp_sol_matrix[var_id, primal_sp_sol_id] = var_val
        for (constr_id, var_coef) in coef_matrix[:,var_id]
            if haskey(coef_matrix, Pair{ConstrId,varId}(cut_id, primal_sp_sol_id))
                coef_matrix[constr_id, primal_sp_sol_id] = coef_matrix[constr_id, primal_sp_sol_id] + var_val * var_coef
            else
                coef_matrix[constr_id, primal_sp_sol_id] = var_val * var_coef
            end
        end
    end

    return primal_sp_sol_var
end

function setdualspsol!(f::Formulation,
                       name::String,
                       sol::DualSolution{S},
                       duty::Type{<:AbstractConstrDuty};
                       kind::ConstrKind = Core,
                       sense::ConstrSense = Less,
                       inc_val::Float64 = 0.0,
                       is_active::Bool = true,
                       is_explicit::Bool = true,
                       moi_index::MoiConstrIndex = MoiConstrIndex()) where {S}
    
    cut_id = generateconstrid(f)
    cut_data =  ConstrData(getvalue(sol), kind, sense, inc_val, is_active, is_explicit)
    cut_constr = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)

    coef_matrix = getcoefmatrix(f)
    dual_sp_sol_matrix = getdualspsolmatrix(f)

    addconstr!(f, cut_constr)
    
    for (constr_id, constr_val) in sol
        dual_sp_sol_matrix[constr_id, cut_id] = constr_val
        for (var_id, var_coef) in coef_matrix[constr_id,:]
            if haskey( coef_matrix, Pair{ConstrId,varId}(cut_id, var_id))
                coef_matrix[cut_id, var_id] = coef_matrix[cut_id, var_id] + constr_val * var_coef
            else
                coef_matrix[cut_id, var_id] = constr_val * var_coef
            end           
        end
    end

    return cut_constr
end

"Adds `Variable` `var` to `Formulation` `f`."
function addvar!(f::Formulation, var::Variable)
    add!(f.buffer, var)
    return addvar!(f.manager, var)
end

"Deactivates a variable or a constraint in the formulation"
function deactivate!(f::Formulation, varconstr::AbstractVarConstr)
    remove!(f.buffer, varconstr)
    set_cur_is_active(varconstr, false)
    return
end
deactivate!(f::Formulation, id::Id) = deactivate!(f, getelem(f, id))

"Activates a variable in the formulation"
function activate!(f::Formulation, id::Id)
    varconstr = getelem(f, id)
    add!(f.buffer, varconstr)
    set_cur_is_active(varconstr, true)
    return
end

function addprimalspsol!(f::Formulation, var::Variable)
    return addprimalspsol!(f.manager, var)
end

function clonevar!(dest::Formulation, src::Formulation, var::Variable)
    addvar!(dest, var)
    return clonevar!(dest.manager, src.manager, var)
end

"Creates a `Constraint` according to the parameters passed and adds it to `Formulation` `f`."
function setconstr!(f::Formulation,
                     name::String,
                     duty::Type{<:AbstractConstrDuty};
                     rhs::Float64 = 0.0,
                     kind::ConstrKind = Core,
                     sense::ConstrSense = Greater,
                     inc_val::Float64 = 0.0,
                     is_active::Bool = true,
                     is_explicit::Bool = true,
                     moi_index::MoiConstrIndex = MoiConstrIndex(),
                     members = nothing)
    id = generateconstrid(f)
    c_data = ConstrData(rhs, kind, sense,  inc_val, is_active, is_explicit)
    c = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)
    members != nothing && setmembers!(f, c, members)
    return addconstr!(f, c)
end

"Adds `Constraint` `constr` to `Formulation` `f`."
function addconstr!(f::Formulation, constr::Constraint)
    add!(f.buffer, constr)
    return addconstr!(f.manager, constr)
end

function enforce_integrality!(f::Formulation)
    @logmsg LogLevel(-1) string("Enforcing integrality of formulation ", getuid(f))
    for (v_id, v) in filter(_active_explicit_, getvars(f))
        getcurkind(v) == Integ && continue
        getcurkind(v) == Binary && continue
        if (getduty(v) == MasterCol || getperenekind(v) != Continuous)
            @logmsg LogLevel(-3) string("Setting kind of var ", getname(v), " to Integer")
            setkind!(f, v, Integ)
        end
    end
    return
end

function relax_integrality!(f::Formulation)
    @logmsg LogLevel(-1) string("Relaxing integrality of formulation ", getuid(f))
    for (v_id, v) in filter(_active_explicit_, getvars(f))
        getcurkind(v) == Continuous && continue
        @logmsg LogLevel(-3) string("Setting kind of var ", getname(v), " to continuous")
        setkind!(f, v, Continuous)
    end
    return
end

"Activates a constraint in the formulation"
function activateconstr!(f::Formulation, id::Id{Constraint})
    c = getvar(f, id)
    add!(f.buffer, c)
    set_cur_is_active(c, true)
    return
end

function cloneconstr!(dest::Formulation, src::Formulation, constr::Constraint)
    addconstr!(dest, constr)
    return cloneconstr!(dest.manager, src.manager, constr)
end

function setmembers!(f::Formulation, v::Variable, members::ConstrMembership)
    # Compute column vector record partial solution
    # This adds the column to the convexity constraints automatically
    # since the setup variable is in the sp solution and it has a
    # a coefficient of 1.0 in the convexity constraints
    coef_matrix = getcoefmatrix(f)
    primalspsol_matrix = getprimalspsolmatrix(f)
    id = getid(v)
    for (constr_id, coeff) in members
        coef_matrix[constr_id, id] = coeff
    end
    return
end

function setmembers!(f::Formulation, constr::Constraint, members)
    @logmsg LogLevel(-2) string("Setting members of constraint ", getname(constr))
    coef_matrix = getcoefmatrix(f)
    primal_sp_sols = getprimalspsolmatrix(f)
    constr_id = getid(constr)
    @logmsg LogLevel(-4) "Members are : ", members
    for (var_id, member_coeff) in members
        # Add coef for its own variables
        v = getvar(f, var_id)
        coef_matrix[constr_id,var_id] = member_coeff
        @logmsg LogLevel(-4) string("Adidng variable ", getname(v), " with coeff ", member_coeff)
        # And for all columns having its own variables
        for (col_id, coeff) in primal_sp_sols[var_id,:]
            @logmsg LogLevel(-4) string("Adding column ", getname(getvar(f, col_id)), " with coeff ", coeff * member_coeff)
            coef_matrix[constr_id,col_id] = coeff * member_coeff
        end
    end
    return
end

function register_objective_sense!(f::Formulation, min::Bool)
    if min
        f.obj_sense = MinSense
    else
        f.obj_sense = MaxSense
    end
    return
end

function remove_from_optimizer!(ids::Set{Id{T}}, f::Formulation) where {
    T <: AbstractVarConstr}
    for id in ids
        vc = getelem(f, id)
        @logmsg LogLevel(-3) string("Removing varconstr of name ", getname(vc))
        remove_from_optimizer!(f.moi_optimizer, vc)
    end
    return
end

function sync_solver(f::Formulation)
    @logmsg LogLevel(-1) string("Synching formulation ", getuid(f))
    optimizer = get_optimizer(f)
    buffer = f.buffer
    matrix = getcoefmatrix(f)
    # Remove constrs
    @logmsg LogLevel(-2) string("Removing constraints")
    remove_from_optimizer!(buffer.constr_buffer.removed, f)
    # Remove vars
    @logmsg LogLevel(-2) string("Removing variables")
    remove_from_optimizer!(buffer.var_buffer.removed, f)
    # Add vars
    for id in buffer.var_buffer.added
        v = getvar(f, id)
        @logmsg LogLevel(-2) string("Adding variable ", getname(v))
        add_to_optimzer!(optimizer, v)
    end
    # Add constrs
    for id in buffer.constr_buffer.added
        c = getconstr(f, id)
        @logmsg LogLevel(-2) string("Adding constraint ", getname(c))
        add_to_optimzer!(optimizer, c, filter(_active_explicit_, matrix[id,:]))
    end
    # Update variable costs
    for id in buffer.changed_cost
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        update_cost_in_optimizer(optimizer, getvar(f, id))
    end
    # Update variable bounds
    for id in buffer.changed_bound
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing bounds of variable " getname(getvar(f,id))
        @logmsg LogLevel(-3) string("New lower bound is ", getcurlb(getvar(f,id)))
        @logmsg LogLevel(-3) string("New upper bound is ", getcurub(getvar(f,id)))
        update_bounds_in_optimizer(optimizer, getvar(f, id))
    end
    # Update variable kind
    for id in buffer.changed_kind
        (id in buffer.var_buffer.added || id in buffer.var_buffer.removed) && continue
        @logmsg LogLevel(-2) "Changing kind of variable " getname(getvar(f,id))
        @logmsg LogLevel(-3) string("New kind is ", getcurkind(getvar(f,id)))
        enforce_var_kind_in_optimizer(optimizer, getvar(f,id))
    end
    # Update constraint rhs
    for id in buffer.changed_rhs
        @warn "Update of constraint rhs not yet implemented"
    end
    # Update matrix
    # First check if should update members of just-added vars
    matrix = getcoefmatrix(f)
    for id in buffer.var_buffer.added
        for (constr_id, coeff) in filter(_active_explicit_, matrix[:,id])
            constr_id in buffer.constr_buffer.added && continue
            c = getconstr(f, constr_id)
            update_constr_member_in_optimizer(optimizer, c, getvar(f, id), coeff)
        end
    end
    # Then updated the rest of the matrix coeffs
    for ((c_id, v_id), coeff) in buffer.reset_coeffs
        # Ignore modifications involving vc's that were removed
        (c_id in buffer.constr_buffer.removed || v_id in buffer.var_buffer.removed) && continue
        c = getconstr(f, c_id)
        v = getvar(f, v_id)
        @logmsg LogLevel(-2) string("Setting matrix coefficient: (", getname(c), ",", getname(v), ") = ", coeff)
        # @logmsg LogLevel(1) string("Setting matrix coefficient: (", getname(c), ",", getname(v), ") = ", coeff)
        update_constr_member_in_optimizer(optimizer, c, v, coeff)
    end
    _reset_buffer!(f)
    return
end

"Calls optimization routine for `Formulation` `f`."
function optimize!(form::Formulation)
    @logmsg LogLevel(-1) string("Optimizing formulation ", getuid(form))
    @logmsg LogLevel(-3) "Coluna formulation before sync: "
    @logmsg LogLevel(-3) form
    @logmsg LogLevel(-3) "MOI formulation before sync: "
    # _show_optimizer(form.moi_optimizer)
    sync_solver(form)
    @logmsg LogLevel(-2) "Coluna formulation after sync: "
    @logmsg LogLevel(-2) form
    @logmsg LogLevel(-2) "MOI formulation after sync: "
    # @show form
    # _show_optimizer(form.moi_optimizer)

#     setup_solver(f.moi_optimizer, f, solver_info)

    call_moi_optimize_with_silence(form.moi_optimizer)
    result = OptimizationResult{getobjsense(form)}()
    status = MOI.get(form.moi_optimizer, MOI.TerminationStatus())
    @logmsg LogLevel(-2) string("Optimization finished with status: ", status)
    if MOI.get(form.moi_optimizer, MOI.ResultCount()) >= 1
        primal_sols = retrieve_primal_sols(
            form, filter(_active_explicit_ , getvars(form))
        )
        result.primal_sols = primal_sols
        result.primal_bound = getbound(primal_sols[1])
        dual_sols = retrieve_dual_sols(form, filter(_active_explicit_ , getconstrs(form)))
        @logmsg LogLevel(-2) string("Primal bound is ", primal_sols[1].bound)
        dual_sols != nothing && @logmsg LogLevel(-2) string("Dual bound is ", dual_sols[1].bound)
        if dual_sols != nothing
            result.dual_sols = dual_sols
            result.dual_bound = getbound(dual_sols[1])
        end
    else
        @warn "Solver has no result to show."
        result.feasible = false
    end
    return result
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
        primal_sol = PrimalSolution(form, new_obj_val, new_sol)
        push!(primal_sols, primal_sol)
    end
    return primal_sols
end

function retrieve_dual_sols(form::Formulation, constrs::ConstrDict)
    # TODO check if supported by solver
    if MOI.get(form.moi_optimizer, MOI.DualStatus()) != MOI.FEASIBLE_POINT
        # println("dual status is : ", MOI.get(form.moi_optimizer, MOI.DualStatus()))
        return nothing
    end
    ObjSense = getobjsense(form)
    dual_sols = DualSolution{ObjSense}[]
    for res_idx in 1:MOI.get(get_optimizer(form), MOI.ResultCount())
        new_sol = Dict{ConstrId,Float64}()
        new_obj_val = obj_bound = MOI.get(form.moi_optimizer, MOI.ObjectiveValue())
        fill_dual_sol(form.moi_optimizer, new_sol, constrs)
        dual_sol = DualSolution(form, obj_bound, new_sol)
        push!(dual_sols, dual_sol)
    end
    return dual_sols
end

function resetsolvalue(form::Formulation, sol::PrimalSolution{S}) where {S}
    val = sum(getcurcost(getvar(form, var_id)) * value for (var_id, value) in sol)
    setvalue!(sol, val)
    return val
end

function resetsolvalue(form::Formulation, sol::DualSolution{S}) where {S}
    val = sum(getcurrhs(getvar(form, constr_id)) * value for (constr_id, value) in sol)
    setvalue!(sol, val)
    return val
end



function computereducedcost(form::Formulation, var_id, dual_sol::DualSolution) 

    var = getvar(form, var_id)
    cost = getcurcost(var)
    coefficient_matrix = getcoefmatrix(form)
    for (constr_id, dual_val) in getsol(dual_sol)
        coeff = coefficient_matrix[constr_id, var_id]
        cost = cost - dual_val * coeff
    end
    
    return cost
end

function computereducedrhs(form::Formulation, constr_id, primal_sol::PrimalSolution) 

    constr = getvar(form, constr_id)
    rhs = getcurrhs(constr)
    coefficient_matrix = getcoefmatrix(form)
    
    for (var_id, primal_val) in getsol(primal_sol)
        coeff = coefficient_matrix[constr_id, var_id]
        rhs = rhs - primal_val * coeff
    end
    
    return rhs
end

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
    if getsense(constr_data) == Equal
        op = "=="
    elseif getsense(constr_data) == Greater
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

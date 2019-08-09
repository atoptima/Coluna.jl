"""
    Formulation{Duty<:AbstractFormDuty}

Representation of a formulation which is typically solved by either a MILP or a dynamic program solver.

Such solver must be interfaced with MOI and its pointer is stored in the field `optimizer`.
"""
mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::Int
    var_counter::Counter
    constr_counter::Counter
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master

    optimizer::AbstractOptimizer
    manager::FormulationManager
    obj_sense::Type{<:AbstractObjSense}

    buffer::FormulationBuffer
end

"""
    Formulation{D}(form_counter::Counter,
                   parent_formulation = nothing,
                   obj_sense::Type{<:AbstractObjSense} = MinSense
                   ) where {D<:AbstractFormDuty}

Constructs a `Formulation` of duty `D` for which the objective sense is `obj_sense`.
"""
function Formulation{D}(form_counter::Counter;
                        parent_formulation = nothing,
                        obj_sense::Type{<:AbstractObjSense} = MinSense
                        ) where {D<:AbstractFormDuty}
    return Formulation{D}(
        getnewuid(form_counter), Counter(), Counter(),
        parent_formulation, NoOptimizer(), FormulationManager(),
        obj_sense, FormulationBuffer()
    )
end

"Returns true iff a `Variable` of `Id` `id` was already added to `Formulation` `f`."
haskey(f::Formulation, id::Id) = haskey(f.manager, id)

"Returns the `Variable` whose `Id` is `id` if such variable is in `Formulation` `f`."
getvar(f::Formulation, id::VarId) = getvar(f.manager, id)

"Returns the value of the variable counter of `Formulation` `f`."
getvarcounter(f::Formulation) = f.var_counter.value
getconstrcounter(f::Formulation) = f.constr_counter.value

"Returns the `Constraint` whose `Id` is `id` if such constraint is in `Formulation` `f`."
getconstr(f::Formulation, id::ConstrId) = getconstr(f.manager, id)

"Returns all the variables in `Formulation` `f`."
getvars(f::Formulation) = getvars(f.manager)

"Returns all the constraints in `Formulation` `f`."
getconstrs(f::Formulation) = getconstrs(f.manager)

"Returns the representation of the coefficient matrix stored in the formulation manager."
getcoefmatrix(f::Formulation) = getcoefmatrix(f.manager)
getprimaldwspsolmatrix(f::Formulation) = getprimaldwspsolmatrix(f.manager)
getdualbendspsolmatrix(f::Formulation) = getdualbendspsolmatrix(f.manager)
getprimalbendspsolmatrix(f::Formulation) = getprimalbendspsolmatrix(f.manager)
getexpressionmatrix(f::Formulation) = getexpressionmatrix(f.manager)

"Returns the `uid` of `Formulation` `f`."
getuid(f::Formulation) = f.uid

"Returns the objective function sense of `Formulation` `f`."
getobjsense(f::Formulation) = f.obj_sense

"Returns the `AbstractOptimizer` of `Formulation` `f`."
getoptimizer(f::Formulation) = f.optimizer

getelem(f::Formulation, id::VarId) = getvar(f, id)
getelem(f::Formulation, id::ConstrId) = getconstr(f, id)

generatevarid(f::Formulation) = VarId(getnewuid(f.var_counter), f.uid)
generateconstrid(f::Formulation) = ConstrId(getnewuid(f.constr_counter), f.uid)

getmaster(f::Formulation{<:AbstractSpDuty}) = f.parent_formulation
getreformulation(f::Formulation{<:AbstractMasterDuty}) = f.parent_formulation
getreformulation(f::Formulation{<:AbstractSpDuty}) = getmaster(f).parent_formulation

_reset_buffer!(f::Formulation) = f.buffer = FormulationBuffer()

"""
    setcost!(f::Formulation, v::Variable, new_cost::Float64)
Sets `v.cur_data.cost` as well as the cost of `v` in `f.optimizer` to be 
euqal to `new_cost`. Change on `f.optimizer` will be buffered.
"""
function setcost!(f::Formulation, v::Variable, new_cost::Float64)
    setcurcost!(v, new_cost)
    change_cost!(f.buffer, v)
end

"""
    setcurcost!(f::Formulation, v::Variable, new_cost::Float64)

Sets `v.cur_data.cost` as well as the cost of `v` in `f.optimizer` to be
euqal to `new_cost`. Change on `f.optimizer` will be buffered.
"""
function setcurcost!(f::Formulation, v::Variable, new_cost::Float64)
    setcurcost!(v, new_cost)
    change_cost!(f.buffer, v)
end

function setcurrhs!(f::Formulation, c::Constraint, new_rhs::Float64)
    setcurrhs!(c, new_rhs)
    change_rhs!(f.buffer, c)
end

"""
    setub!(f::Formulation, v::Variable, new_ub::Float64)

Sets `v.cur_data.ub` as well as the bounds constraint of `v` in `f.optimizer`
according to `new_ub`. Change on `f.optimizer` will be buffered.
"""
function setub!(f::Formulation, v::Variable, new_ub::Float64)
    setcurub!(v, new_ub)
    change_bound!(f.buffer, v)
end

"""
    setlb!(f::Formulation, v::Variable, new_lb::Float64)

Sets `v.cur_data.lb` as well as the bounds constraint of `v` in `f.optimizer`
according to `new_lb`. Change on `f.optimizer` will be buffered.
"""
function setlb!(f::Formulation, v::Variable, new_lb::Float64)
    setcurlb!(v, new_lb)
    change_bound!(f.buffer, v)
end

"""
    setkind!(f::Formulation, v::Variable, new_kind::VarKind)

Sets `v.cur_data.kind` as well as the kind constraint of `v` in `f.optimizer`
according to `new_kind`. Change on `f.optimizer` will be buffered.
"""
function setkind!(f::Formulation, v::Variable, new_kind::VarKind)
    setcurkind(v, new_kind)
    change_kind!(f.buffer, v)
end

"""
    setrhs!(f::Formulation, c::Constraint, new_rhs::Float64)

Sets `c.cur_data.rhs` as well as the rhs of `c` in `f.optimizer` 
according to `new_rhs`. Change on `f.optimizer` will be buffered.
"""
function setrhs!(f::Formulation, c::Constraint, new_rhs::Float64)
    setcurrhs!(c, new_rhs)
    change_rhs!(f.buffer, c)
end

"""
    set_matrix_coeff!(f::Formulation, v_id::Id{Variable}, c_id::Id{Constraint}, new_coeff::Float64)

Buffers the matrix modification in `f.buffer` to be sent to `f.optimizer` right before next call to optimize!.
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
                  members::Union{ConstrMembership,Nothing} = nothing,
                  id = generatevarid(f))
    v_data = VarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
    v = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    members != nothing && setmembers!(f, v, members)
    return addvar!(f, v)
end

function setprimaldwspsol!(master_form::Formulation,
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
                         moi_index::MoiVarIndex = MoiVarIndex()) where {S<:AbstractObjSense}

    #master_form = sp_form.parent_formulation
    mastcol_id = generatevarid(master_form)
    mastcol_data = VarData(getvalue(sol), lb, ub, kind, sense, inc_val, is_active, is_explicit)
    mastcol = Variable(mastcol_id, name, duty; var_data = mastcol_data, moi_index = moi_index)

    master_coef_matrix = getcoefmatrix(master_form)
    primalspsol_matrix = getprimaldwspsolmatrix(master_form)

    for (var_id, var_val) in sol
        primalspsol_matrix[var_id, mastcol_id] = var_val
        for (constr_id, var_coef) in master_coef_matrix[:,var_id]
            master_coef_matrix[constr_id, mastcol_id] += var_val * var_coef
        end
    end

    return addvar!(master_form, mastcol)
end



function setprimaldualbendspsol!(master_form::Formulation,
                                 sp_form::Formulation,
                                 name::String,
                                 primal_sol::PrimalSolution{S},
                                 dual_sol::DualSolution{S},
                                 duty::Type{<:AbstractConstrDuty};
                                 kind::ConstrKind = Core,
                                 sense::ConstrSense = Greater,
                                 inc_val::Float64 = -1.0,
                                 is_active::Bool = true,
                                 is_explicit::Bool = true,
                                 moi_index::MoiConstrIndex = MoiConstrIndex()) where {S<:AbstractObjSense}

   


    benders_cut = setconstr!(master_form,
                     name,
                     duty;
                     rhs = getvalue(dual_sol),
                     kind = Core,
                     sense = sense,
                     inc_val = inc_val,
                     is_active = is_active,
                     is_explicit = is_explicit,
                     moi_index = moi_index)
    cut_id = getid(benders_cut)
    
    #==cut_id = generateconstrid(master_form)
    cut_data = ConstrData(getvalue(dual_sol), kind, sense, inc_val, is_active, is_explicit)
    cut = Constraint(cut_id, name, duty; constr_data = cut_data, moi_index = moi_index)
    benders_cut = addconstr!(master_form, cut)==#

    @show primal_sol
    
    @show dual_sol
    
    
    master_coef_matrix = getcoefmatrix(master_form)
    sp_coef_matrix = getcoefmatrix(sp_form)
    primalbendspsol_matrix = getprimalbendspsolmatrix(master_form)
    dualbendspsol_matrix = getdualbendspsolmatrix(master_form)

    @show "********** building cut *************"
    for (constr_id, constr_val) in dual_sol
        constr = getconstr(sp_form, constr_id)
        #@show " dual sol includes " constr constr_val
        if getduty(constr) <: AbstractBendSpMasterConstr
            dualbendspsol_matrix[constr_id, cut_id] = constr_val
            for (var_id, constr_coef) in sp_coef_matrix[constr_id,:]
                var = getvar(sp_form, var_id)
                #@show " constr  includes var " var constr_val constr_coef
                #@show getconstr(master_form, cut_id)
                #@show master_coef_matrix[cut_id,:]
                #@show getname(var)
                #@show master_coef_matrix
                if getduty(var) <: AbstractBendSpSlackMastVar
                    if haskey(master_coef_matrix, cut_id, var_id)
                        master_coef_matrix[cut_id, var_id] += constr_val * constr_coef
                    else
                        master_coef_matrix[cut_id, var_id] = constr_val * constr_coef
                    end
                end
            end
        end
    end 
    @show "cut coefs *************"  master_coef_matrix[cut_id,:]

      
   #== for (constr_id, constr_val) in dual_sol
        dualbendspsol_matrix[constr_id, dps_id] = constr_val
        @show getconstr(master_form, constr_id)
        @show master_coef_matrix[constr_id,:]
        for (var_id, constr_coef) in master_coef_matrix[constr_id,:]
            master_coef_matrix[dps_id, var_id] += constr_val * constr_coef
        end
    end==#


    @show benders_cut

    for (var_id, var_val) in primal_sol
        primalbendspsol_matrix[var_id, cut_id] = var_val
    end

    return benders_cut
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
                     members = nothing,
                     id = generateconstrid(f))
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

function setmembers!(f::Formulation, v::Variable, members::ConstrMembership)
    # Compute column vector record partial solution
    # This adds the column to the convexity constraints automatically
    # since the setup variable is in the sp solution and it has a
    # a coefficient of 1.0 in the convexity constraints
    coef_matrix = getcoefmatrix(f)
    primalspsol_matrix = getprimaldwspsolmatrix(f)
    id = getid(v)
    for (constr_id, coeff) in members
        coef_matrix[constr_id, id] = coeff
    end
    return
end

function setmembers!(f::Formulation, constr::Constraint, members)
    @logmsg LogLevel(-2) string("Setting members of constraint ", getname(constr))
    coef_matrix = getcoefmatrix(f)
    primal_dwsp_sols = getprimaldwspsolmatrix(f)
    constr_id = getid(constr)
    @logmsg LogLevel(-4) "Members are : ", members
    for (var_id, member_coeff) in members
        # Add coef for its own variables
        v = getvar(f, var_id)
        coef_matrix[constr_id,var_id] = member_coeff
        @logmsg LogLevel(-4) string("Adidng variable ", getname(v), " with coeff ", member_coeff)
        # And for all columns having its own variables
        for (col_id, coeff) in primal_dwsp_sols[var_id,:]
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
        remove_from_optimizer!(f.optimizer, vc)
    end
    return
end

function resetsolvalue(form::Formulation, sol::PrimalSolution{S}) where {S<:AbstractObjSense}
    val = sum(getperenecost(getvar(form, var_id)) * value for (var_id, value) in sol)
    setvalue!(sol, val)
    return val
end

function resetsolvalue(form::Formulation, sol::DualSolution{S}) where {S<:AbstractObjSense}
    val = sum(getperenerhs(getconstr(form, constr_id)) * value for (constr_id, value) in sol)
    setvalue!(sol, val)
    return val
end

function computereducedcost(form::Formulation, var_id::Id{Variable}, dual_sol::DualSolution{S})  where {S<:AbstractObjSense}
    var = getvar(form, var_id)
    rc = getperenecost(var)
    coefficient_matrix = getcoefmatrix(form)
    for (constr_id, dual_val) in getsol(dual_sol)
        coeff = coefficient_matrix[constr_id, var_id]
        if getobjsense(form) == MinSense
            rc -= dual_val * coeff
        else
            rc += dual_val * coeff
        end
    end
    return rc
end

function computereducedrhs(form::Formulation, constr_id::Id{Constraint}, primal_sol::PrimalSolution{S})  where {S<:AbstractObjSense}
    constr = getconstr(form,constr_id)
    crhs = getperenerhs(constr)
    coefficient_matrix = getcoefmatrix(form)
    for (var_id, primal_val) in getsol(primal_sol)
        coeff = coefficient_matrix[constr_id, var_id]
        crhs -= primal_val * coeff
    end
    return crhs
end

"Calls optimization routine for `Formulation` `f`."
function optimize!(form::Formulation)
    @logmsg LogLevel(-1) string("Optimizing formulation ", getuid(form))
    @logmsg LogLevel(-3) form
    res = optimize!(form, getoptimizer(form))
    @logmsg LogLevel(-2) string("Optimization finished with result:")
    @logmsg LogLevel(-2) res
    return res
end

function initialize_optimizer!(form::Formulation, builder::Union{Function})
    form.optimizer = builder()
    if form.optimizer isa MoiOptimizer
        f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0)
        MOI.set(form.optimizer.inner, MoiObjective(), f)
        set_obj_sense!(form.optimizer, getobjsense(form))
    end
    return
end

function _show_obj_fun(io::IO, f::Formulation)
    print(io, getobjsense(f), " ")
    vars = filter(_explicit_, getvars(f))
    ids = sort!(collect(keys(vars)), by = getsortid)
    for id in ids
        name = getname(vars[id])
        cost = getcost(getcurdata(vars[id]))
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

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
getprimalsolmatrix(f::Formulation) = getprimalsolmatrix(f.manager)
getdualsolmatrix(f::Formulation) = getdualsolmatrix(f.manager)
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

addprimalsol!(
    form::Formulation,
    sol::PrimalSolution{S},
    sol_id::VarId
) where {S<:AbstractObjSense} = addprimalsol!(form.manager, sol, sol_id)

function setprimalsol!(
    form::Formulation,
    newprimalsol::PrimalSolution{S}
)::Tuple{Bool,VarId} where {S<:AbstractObjSense}
    ### check if primalsol exists does takes place here along the coeff update

    primal_sols = getprimalsolmatrix(form)

    for (sol_id, sol) in columns(primal_sols)
        #@show sol_idx
        is_identical = true
        for (var_id, var_val) in getrecords(sol)
            if !haskey(newprimalsol.sol, var_id)
                is_identical = false
                break
            end
        end
        if !is_identical
            break
        end
 
        for (var_id, var_val) in getrecords(newprimalsol.sol)
            #@show (var_id, var_val)
            if !haskey(sol, var_id)
                is_identical = false
                break
            end
        
            if sol[var_id] != var_val
                is_identical = false
                break
            end
        end
        if is_identical
            return (false, sol_id)
        end
    end
    
    ### else not identical to any existing column
    new_sol_id = generatevarid(form)
    addprimalsol!(form, newprimalsol, new_sol_id)
    return (true, new_sol_id)
end

adddualsol!(
    form::Formulation,
    dualsol::DualSolution{S},
    dualsol_id::ConstrId
) where {S<:AbstractObjSense} = adddualsol!(form.manager, dualsol, dualsol_id)


function setdualsol!(
    form::Formulation,
    new_dual_sol::DualSolution{S}
)::Tuple{Bool,ConstrId} where {S<:AbstractObjSense}
    ### check if dualsol exists  take place here along the coeff update

    prev_dual_sols = getdualsolmatrix(form)

    for (prev_dual_sol_id, prev_dual_sol) in columns(prev_dual_sols)
        #@show col
        is_identical = true
        for (constr_id, constr_val) in getrecords(prev_dual_sol)
            #@show (var_id, var_val)
            if !haskey(new_dual_sol.sol, constr_id)
                is_identical = false
                break
            end
        end
        if !is_identical
            break
        end

        factor = 1.0
        scaling_in_place = false
        for (constr_id, constr_val) in getrecords(new_dual_sol.sol)
            #@show (var_id, var_val)
            if !haskey(prev_dual_sol, constr_id)
                is_identical = false
                break
            end
            
            if prev_dual_sol[constr_id] != factor * constr_val
                if !scaling_in_place
                    scaling_in_place = true
                    factor = prev_dual_sol[constr_id] / constr_val
                else
                    is_identical = false
                    break
                end
            end
        end
        if is_identical
            return (false, prev_dual_sol_id)
        end
    end
    

    ### else not identical to any existing dual sol
    new_dual_sol_id = generateconstrid(form)
    adddualsol!(form, new_dual_sol, new_dual_sol_id)
    return (true, new_dual_sol_id)
end


function setcol_from_sp_primalsol!(
    masterform::Formulation,
    spform::Formulation,
    sol_id::VarId,
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
    moi_index::MoiVarIndex = MoiVarIndex()
) 
    mast_col_id = sol_id
    mast_col_data = VarData(
        cost, lb, ub, kind, sense, inc_val, is_active, is_explicit
    )
    mast_col = Variable(
        mast_col_id, name, duty;
        var_data = mast_col_data,
        moi_index = moi_index
    )

    master_coef_matrix = getcoefmatrix(masterform)
    primal_sols = getprimalsolmatrix(spform)
    sp_sol = primal_sols[:,sol_id]

    for (sp_var_id, sp_var_val) in sp_sol
        for (master_constr_id, sp_var_coef) in master_coef_matrix[:,sp_var_id]
            master_coef_matrix[master_constr_id, mast_col_id] += sp_var_val * sp_var_coef
        end
    end

    return addvar!(masterform, mast_col)
end

function setcut_from_sp_dualsol!(
    masterform::Formulation,
    spform::Formulation,
    dualsol_id::ConstrId,
    name::String,
    duty::Type{<:AbstractConstrDuty};
    rhs::Float64 = 0.0,
    kind::ConstrKind = Core,
    sense::ConstrSense = Greater,
    inc_val::Float64 = -1.0, 
    is_active::Bool = true,
    is_explicit::Bool = true,
    moi_index::MoiConstrIndex = MoiConstrIndex()
) 
    benders_cut_id = dualsol_id #generateconstrid(mastform)
    benders_cut_data = ConstrData(
        rhs, Core, sense, inc_val, is_active, is_explicit
    )
    benders_cut = Constraint(
        benders_cut_id, name, duty;
        constr_data = benders_cut_data, 
        moi_index = moi_index
    )

    master_coef_matrix = getcoefmatrix(mastform)
    sp_coef_matrix = getcoefmatrix(spform)
    dual_sols = getdualsolmatrix(spform)
    sp_dualsol = dual_sols[dualsol_id,:]

    for (ds_constr_id, ds_constr_val) in sp_dualsol
        ds_constr = getconstr(spform, ds_constr_id)
        if getduty(ds_constr) <: AbstractBendSpMasterConstr
            for (master_var_id, sp_constr_coef) in sp_coef_matrix[ds_constr_id,:]
                var = getvar(spform, master_var_id)
                if getduty(var) <: AbstractBendSpSlackMastVar
                    master_coef_matrix[benders_cut_id, master_var_id] += ds_constr_val * sp_constr_coef
                end
            end
        end
    end 


    return addconstr!(mastform, benders_cut)
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

function deactivate!(f::Formulation, Duty::Type{<:AbstractVarDuty})
    vars = filter(v -> get_cur_is_active(v) && getduty(v) <: Duty, getvars(f))
    for (id, var) in vars
        deactivate!(f, var)
    end
    return
end

function deactivate!(f::Formulation, Duty::Type{<:AbstractConstrDuty})
    constrs = filter(c -> get_cur_is_active(c) && getduty(c) <: Duty, getconstrs(f))
    for (id, constr) in constrs
        deactivate!(f, constr)
    end
    return
end

"Activates a variable in the formulation"
function activate!(f::Formulation, varconstr::AbstractVarConstr)
    add!(f.buffer, varconstr)
    set_cur_is_active(varconstr, true)
    return
end
activate!(f::Formulation, id::Id) = activate!(f, getelem(f, id))

function activate!(f::Formulation, Duty::Type{<:AbstractVarDuty})
    vars = filter(v -> !get_cur_is_active(v) && getduty(v) <: Duty, getvars(f))
    for (id, var) in vars
        activate!(f, var)
    end
end

function activate!(f::Formulation, Duty::Type{<:AbstractConstrDuty})
    constrs = filter(c -> !get_cur_is_active(c) && getduty(c) <: Duty, getconstrs(f))
    for (id, constr) in constrs
        activate!(f, constr)
    end
end

function addprimalsol!(f::Formulation, var::Variable)
    return addprimalsol!(f.manager, var)
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
    for (v_id, v) in Iterators.filter(_active_explicit_, getvars(f))
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
    for (v_id, v) in Iterators.filter(_active_explicit_, getvars(f))
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
    primal_sp_sol_matrix = getprimalsolmatrix(f)
    id = getid(v)
    for (constr_id, coeff) in members
        coef_matrix[constr_id, id] = coeff
    end
    return
end

function setmembers!(f::Formulation, constr::Constraint, members)
    @logmsg LogLevel(-2) string("Setting members of constraint ", getname(constr))
    coef_matrix = getcoefmatrix(f)
    primal_dwsp_sols = getprimalsolmatrix(f)
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

function computesolvalue(form::Formulation, sol_vec::PrimalSolVector) 
    val = sum(getperenecost(getvar(form, var_id)) * value for (var_id, value) in sol_vec)
    return val
end


function computesolvalue(form::Formulation, sol::PrimalSolution{S}) where {S<:AbstractObjSense}
    val = sum(getperenecost(getvar(form, var_id)) * value for (var_id, value) in sol)
    return val
end

function resetsolvalue!(form::Formulation, sol::PrimalSolution{S}) where {S<:AbstractObjSense}
    val = computesolvalue(form, sol)
    setvalue!(sol, val)
    return val
end

function computesolvalue(form::Formulation, sol_vec::DualSolVector) 
    val = sum(getperenerhs(getconstr(form, constr_id)) * value for (constr_id, value) in sol)
    return val 
end

function computesolvalue(form::Formulation, sol::DualSolution{S}) where {S<:AbstractObjSense}
    val = sum(getperenerhs(getconstr(form, constr_id)) * value for (constr_id, value) in sol)
    return val 
end

function resetsolvalue!(form::Formulation, sol::DualSolution{S}) where {S<:AbstractObjSense}
    val = computesolvalue(form, sol)
    setvalue!(sol, val)
    return val 
end

function computereducedcost(form::Formulation, var_id::Id{Variable}, dualsol::DualSolution{S})  where {S<:AbstractObjSense}
    var = getvar(form, var_id)
    rc = getperenecost(var)
    coefficient_matrix = getcoefmatrix(form)
    for (constr_id, dual_val) in getsol(dualsol)
        coeff = coefficient_matrix[constr_id, var_id]
        if getobjsense(form) == MinSense
            rc -= dual_val * coeff
        else
            rc += dual_val * coeff
        end
    end
    return rc
end

function computereducedrhs(form::Formulation, constr_id::Id{Constraint}, primalsol::PrimalSolution{S})  where {S<:AbstractObjSense}
    constr = getconstr(form,constr_id)
    crhs = getperenerhs(constr)
    coefficient_matrix = getcoefmatrix(form)
    for (var_id, primal_val) in getsol(primalsol)
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

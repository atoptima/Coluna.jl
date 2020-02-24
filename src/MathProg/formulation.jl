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
    obj_sense::Type{<:Coluna.AbstractSense}
    buffer::FormulationBuffer
    storages::StorageDict
end

"""
    Formulation{D}(form_counter::Counter,
                    parent_formulation = nothing,
                    obj_sense::Type{<:Coluna.AbstractSense} = MinSense
                    ) where {D<:AbstractFormDuty}

Constructs a `Formulation` of duty `D` for which the objective sense is `obj_sense`.
"""
function Formulation{D}(form_counter::Counter;
                        parent_formulation = nothing,
                        obj_sense::Type{<:Coluna.AbstractSense} = MinSense
                        ) where {D<:AbstractFormDuty}
    return Formulation{D}(
        getnewuid(form_counter), Counter(), Counter(),
        parent_formulation, NoOptimizer(), FormulationManager(),
        obj_sense, FormulationBuffer(), Dict{Type{<:AbstractStorage}, AbstractStorage}()
    )
end

getstoragedict(form::Formulation)::StorageDict = form.storages

"Returns true iff a `Variable` of `Id` `id` was already added to `Formulation` `form`."
haskey(form::Formulation, id::Id) = haskey(form.manager, id)

"Returns the `Variable` whose `Id` is `id` if such variable is in `Formulation` `form`."
getvar(form::Formulation, id::VarId) = getvar(form.manager, id)

"Returns the value of the variable counter of `Formulation` `form`."
getvarcounter(form::Formulation) = form.var_counter.value
getconstrcounter(form::Formulation) = form.constr_counter.value

"Returns the `Constraint` whose `Id` is `id` if such constraint is in `Formulation` `form`."
getconstr(form::Formulation, id::ConstrId) = getconstr(form.manager, id)

"Returns all the variables in `Formulation` `form`."
getvars(form::Formulation) = getvars(form.manager)

"Returns all the constraints in `Formulation` `form`."
getconstrs(form::Formulation) = getconstrs(form.manager)

"Returns the representation of the coefficient matrix stored in the formulation manager."
getcoefmatrix(form::Formulation) = getcoefmatrix(form.manager)
getprimalsolmatrix(form::Formulation) = getprimalsolmatrix(form.manager)
getprimalsolcosts(form::Formulation) = getprimalsolcosts(form.manager)
getdualsolmatrix(form::Formulation) = getdualsolmatrix(form.manager)
getdualsolrhss(form::Formulation) = getdualsolrhss(form.manager)
getexpressionmatrix(form::Formulation) = getexpressionmatrix(form.manager)


"Returns the `uid` of `Formulation` `form`."
getuid(form::Formulation) = form.uid

"Returns the objective function sense of `Formulation` `form`."
getobjsense(form::Formulation) = form.obj_sense

"Returns the `AbstractOptimizer` of `Formulation` `form`."
getoptimizer(form::Formulation) = form.optimizer

getelem(form::Formulation, id::VarId) = getvar(form, id)
getelem(form::Formulation, id::ConstrId) = getconstr(form, id)

generatevarid(form::Formulation) = VarId(getnewuid(form.var_counter), getuid(form))
generateconstrid(form::Formulation) = ConstrId(getnewuid(form.constr_counter), getuid(form))

getmaster(form::Formulation{<:AbstractSpDuty}) = form.parent_formulation
getreformulation(form::Formulation{<:AbstractMasterDuty}) = form.parent_formulation
getreformulation(form::Formulation{<:AbstractSpDuty}) = getmaster(form).parent_formulation

_reset_buffer!(form::Formulation) = form.buffer = FormulationBuffer()


#= 
function setcurrhs!(form::Formulation, constr::Constraint, new_rhs::Float64)
    setcurrhs!(constr, new_rhs)
    change_rhs!(form.buffer, constr)
end =#


"""
    setrhs!(form::Formulation, c::Constraint, new_rhs::Float64)

Sets `c.cur_data.rhs` as well as the rhs of `c` in `form.optimizer` 
according to `new_rhs`. Change on `form.optimizer` will be buffered.
"""
#= function setrhs!(form::Formulation, constr::Constraint, new_rhs::Float64)
    setcurrhs!(constr, new_rhs)
    change_rhs!(form.buffer, constr)
end =#

"""
    set_matrix_coeff!(form::Formulation, v_id::Id{Variable}, c_id::Id{Constraint}, new_coeff::Float64)

Buffers the matrix modification in `form.buffer` to be sent to `form.optimizer` right before next call to optimize!.
"""
set_matrix_coeff!(
    form::Formulation, var_id::Id{Variable}, constr_id::Id{Constraint}, new_coeff::Float64
) = set_matrix_coeff!(form.buffer, var_id, constr_id, new_coeff)

"Creates a `Variable` according to the parameters passed and adds it to `Formulation` `form`."
function setvar!(form::Formulation,
                 name::String,
                 duty::Duty{Variable};
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
                 id = generatevarid(form))
    if kind == Binary
        lb = (lb < 0.0) ? 0.0 : lb
        ub = (ub > 1.0) ? 1.0 : ub
    end
    v_data = VarData(cost, lb, ub, kind, sense, inc_val, is_active, is_explicit)
    var = Variable(id, name, duty; var_data = v_data, moi_index = moi_index)
    if haskey(form.manager.vars, getid(var))
        error(string("Variable of id ", getid(var), " exists"))
    end
    #= done in _addvar!(form, var)
    form.manager.vars[getid(var)] = var
    form.manager.var_costs[getid(var)] = cost
    form.manager.var_lbs[getid(var)] = lb
    form.manager.var_ubs[getid(var)] = ub
    ==#
    _addvar!(form, var)
    members != nothing && _setmembers!(form, var, members)
    return var
end


"Adds `Variable` `var` to `Formulation` `form`."
function _addvar!(form::Formulation, var::Variable)
    _addvar!(form.manager, var)
    
    if getcurisexplicit(form, var) 
        add!(form.buffer, var)
    end
    return 

end

function addprimalsol!(
    form::Formulation, sol::PrimalSolution{S}, sol_id::VarId
) where {S<:Coluna.AbstractSense}
    cost = 0.0
    for (var_id, var_val) in sol
        var = form.manager.vars[var_id]
        cost += getperenecost(form, var) * var_val
        if getduty(var) <= DwSpSetupVar || getduty(var) <= DwSpPricingVar
            form.manager.primal_sols[var_id, sol_id] = var_val
        end
    end
    form.manager.primal_sol_costs[sol_id] = cost
    return sol_id
end

function setprimalsol!(
    form::Formulation,
    newprimalsol::PrimalSolution{S}
)::Tuple{Bool,VarId} where {S<:Coluna.AbstractSense}
    ### check if primalsol exists does takes place here along the coeff update

    primal_sols = getprimalsolmatrix(form)

    for (sol_id, sol) in columns(primal_sols)
        cost = getprimalsolcosts(form)[sol_id]
        if newprimalsol.bound < cost
             continue
        end
        if newprimalsol.bound > cost
             continue
        end

        is_identical = true
        for (var_id, var_val) in getrecords(sol)
            if newprimalsol[var_id] == 0
                is_identical = false
                break
            end
        end
        if !is_identical
            continue
        end
        
        for (var_id, var_val) in getrecords(newprimalsol.sol)
            if sol[var_id] == 0
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
    new_sol_id = Id{Variable}(generatevarid(form), getuid(form))
    addprimalsol!(form, newprimalsol, new_sol_id)
    return (true, new_sol_id)
end

function adddualsol!(
    form::Formulation,
    dualsol::DualSolution{S},
    dualsol_id::ConstrId
    ) where {S<:Coluna.AbstractSense} 
    
    rhs = 0.0
    for (constr_id, constr_val) in dualsol
        constr = getconstr(form, constr_id)
        rhs += getperenerhs(form, constr) * constr_val 
        if getduty(constr) <= AbstractBendSpMasterConstr
            form.manager.dual_sols[constr_id, dualsol_id] = constr_val
        end
    end
    form.manager.dual_sol_rhss[dualsol_id] = rhs
    
    return dualsol_id
end

function setdualsol!(
    form::Formulation,
    new_dual_sol::DualSolution{S}
)::Tuple{Bool,ConstrId} where {S<:Coluna.AbstractSense}
    ### check if dualsol exists  take place here along the coeff update

    prev_dual_sols = getdualsolmatrix(form)

    for (prev_dual_sol_id, prev_dual_sol) in columns(prev_dual_sols)
        rhs = getdualsolrhss(form)[prev_dual_sol_id]
        factor = 1.0
        if new_dual_sol.bound < rhs
            factor = rhs / new_dual_sol.bound
            
        else
            if new_dual_sol.bound > rhs
                factor = rhs / new_dual_sol.bound
            end 
        end
        
        is_identical = true
        for (constr_id, constr_val) in getrecords(prev_dual_sol)
            if new_dual_sol[constr_id] == 0
                is_identical = false
                break
            end
        end
        if !is_identical
            continue
        end

        for (constr_id, constr_val) in new_dual_sol
            if prev_dual_sol[constr_id] == 0
                is_identical = false
                break
            end
            
            if prev_dual_sol[constr_id] != factor * constr_val
                is_identical = false
                break
            end
        end
        if is_identical
            return (false, prev_dual_sol_id)
        end    
    end
    
    ### else not identical to any existing dual sol
    new_dual_sol_id = Id{Constraint}(generateconstrid(form), getuid(form))
    adddualsol!(form, new_dual_sol, new_dual_sol_id)
    return (true, new_dual_sol_id)
end

function setcol_from_sp_primalsol!(
    masterform::Formulation, spform::Formulation, sol_id::VarId,
    name::String, duty::Duty{Variable}; lb::Float64 = 0.0,
    ub::Float64 = Inf, kind::VarKind = Continuous, sense::VarSense = Positive, 
    inc_val::Float64 = 0.0, is_active::Bool = true, is_explicit::Bool = true,
    moi_index::MoiVarIndex = MoiVarIndex()
) 
    cost = getprimalsolcosts(spform)[sol_id]

    master_coef_matrix = getcoefmatrix(masterform)
    sp_sol = getprimalsolmatrix(spform)[:,sol_id]
    members = MembersVector{Float64}(getconstrs(masterform))

    for (sp_var_id, sp_var_val) in sp_sol
        for (master_constr_id, sp_var_coef) in master_coef_matrix[:,sp_var_id]
            members[master_constr_id] += sp_var_val * sp_var_coef
        end
    end

    mast_col = setvar!(
        masterform, name, duty,
        cost = cost,
        lb = lb,
        ub = ub,
        kind = kind,
        sense = sense,
        inc_val = inc_val,
        is_active = is_active,
        is_explicit = is_explicit,
        moi_index = moi_index,
        members = members,
        id = sol_id
    )
    return mast_col
end

function setcut_from_sp_dualsol!(
    masterform::Formulation,
    spform::Formulation,
    dual_sol_id::ConstrId,
    name::String,
    duty::Duty{Constraint};
    kind::ConstrKind = Core,
    sense::ConstrSense = Greater,
    inc_val::Float64 = -1.0, 
    is_active::Bool = true,
    is_explicit::Bool = true,
    moi_index::MoiConstrIndex = MoiConstrIndex()
) 
    rhs = getdualsolrhss(spform)[dual_sol_id]
    benders_cut_id = dual_sol_id 
    benders_cut_data = ConstrData(
        rhs, Core, sense, inc_val, is_active, is_explicit
    )
    benders_cut = Constraint(
        benders_cut_id, name, duty;
        constr_data = benders_cut_data, 
        moi_index = moi_index
    )
    master_coef_matrix = getcoefmatrix(masterform)
    sp_coef_matrix = getcoefmatrix(spform)
    sp_dual_sol = getdualsolmatrix(spform)[:,dual_sol_id]

    for (ds_constr_id, ds_constr_val) in sp_dual_sol
        ds_constr = getconstr(spform, ds_constr_id)
        if getduty(ds_constr) <= AbstractBendSpMasterConstr
            for (master_var_id, sp_constr_coef) in sp_coef_matrix[ds_constr_id,:]
                var = getvar(spform, master_var_id)
                if getduty(var) <= AbstractBendSpSlackMastVar
                    master_coef_matrix[benders_cut_id, master_var_id] += ds_constr_val * sp_constr_coef
                end
            end
        end
    end 
    _addconstr!(masterform, benders_cut)
    return benders_cut
end


"Deactivates a variable or a constraint in the formulation"
function deactivate!(form::Formulation, varconstr::AbstractVarConstr)
    if getcurisexplicit(form, varconstr)
        remove!(form.buffer, varconstr)
    end
    setcurisactive!(form, varconstr, false)
    return
end
deactivate!(form::Formulation, id::Id) = deactivate!(form, getelem(form, id))


function deactivate!(form::Formulation, duty::Duty{Variable})
    vars = filter(v -> getcurisactive(form,v) && getduty(v) <= duty, getvars(form))
    for (id, var) in vars
        deactivate!(form, var)
    end
    return
end


function deactivate!(form::Formulation, duty::Duty{Constraint})
    constrs = filter(c -> getcurisactive(form,c) && getduty(c) <= duty, getconstrs(form))
    for (id, constr) in constrs
        deactivate!(form, constr)
    end
    return
end

"Activates a variable in the formulation"
function activate!(form::Formulation, varconstr::AbstractVarConstr)
    add!(form.buffer, varconstr)
    setcurisactive!(form, varconstr, true)
    return
end
activate!(form::Formulation, id::Id) = activate!(form, getelem(form, id))


function activate!(form::Formulation, duty::Duty{Variable})
    vars = filter(v -> !getcurisactive(form,v) && getduty(v) <= duty, getvars(form))
    for (id, var) in vars
        activate!(form, var)
    end
end


function activate!(form::Formulation, duty::Duty{Constraint})
    constrs = filter(c -> !getcurisactive(form,c) && getduty(c) <= duty, getconstrs(form))

    for (id, constr) in constrs
        activate!(form, constr)
    end
end

"Creates a `Constraint` according to the parameters passed and adds it to `Formulation` `form`."
function setconstr!(form::Formulation,
                    name::String,
                    duty::Duty{Constraint};
                    rhs::Float64 = 0.0,
                    kind::ConstrKind = Core,
                    sense::ConstrSense = Greater,
                    inc_val::Float64 = 0.0,
                    is_active::Bool = true,
                    is_explicit::Bool = true,
                    moi_index::MoiConstrIndex = MoiConstrIndex(),
                    members = nothing, # todo Union{AbstractDict{VarId,Float64},Nothing}
                    id = generateconstrid(form))
    c_data = ConstrData(rhs, kind, sense,  inc_val, is_active, is_explicit)
    constr = Constraint(id, name, duty; constr_data = c_data, moi_index = moi_index)
    members != nothing && _setmembers!(form, constr, members)
    _addconstr!(form, constr)
    return constr
end

"Adds `Constraint` `constr` to `Formulation` `form`."
function _addconstr!(form::Formulation, constr::Constraint)
    _addconstr!(form.manager, constr)
    
    if getcurisexplicit(form, constr) 
        add!(form.buffer, constr)
    end
    return 
end

function enforce_integrality!(form::Formulation)
    @logmsg LogLevel(-1) string("Enforcing integrality of formulation ", getuid(form))
    for (v_id, v) in Iterators.filter(
        vc -> getcurisactive(form,vc) && getcurisexplicit(form,vc),
        getvars(form)
        )
        getcurkind(form, v) == Integ && continue
        getcurkind(form, v) == Binary && continue
        if (getduty(v) == MasterCol || getperenekind(form, v) != Continuous)
            @logmsg LogLevel(-3) string("Setting kind of var ", getname(form, v), " to Integer")
            setcurkind!(form, v, Integ)
        end
    end
    return
end

function relax_integrality!(form::Formulation)
    @logmsg LogLevel(-1) string("Relaxing integrality of formulation ", getuid(form))
    for (v_id, v) in Iterators.filter(
        vc -> getcurisactive(form,vc) && getcurisexplicit(form,vc),
        getvars(form)
        )
        getcurkind(form, v) == Continuous && continue
        @logmsg LogLevel(-3) string("Setting kind of var ", getname(form, v), " to continuous")
        setcurkind!(form, v, Continuous)
    end
    return
end

"Activates a constraint in the formulation"
function activateconstr!(form::Formulation, constrid::Id{Constraint})
    constr = getconstr(form, constrid)
    if getcurisexplicit(form, constrid) 
        add!(form.buffer, constr)
    end
    setcurisactive(form, constr, true)
    return
end

# TODO : delete
function _setmembers!(form::Formulation, var::Variable, members::ConstrMembership)
    coef_matrix = getcoefmatrix(form)
    id = getid(var)
    for (constr_id, constr_coeff) in members
        coef_matrix[constr_id, id] = constr_coeff
    end
    return
end

function _setmembers!(form::Formulation, var::Variable, members::AbstractDict{ConstrId, Float64})
    coef_matrix = getcoefmatrix(form)
    id = getid(var)
    for (constr_id, constr_coeff) in members
        coef_matrix[constr_id, id] = constr_coeff
    end
    return
end

# TODO : delete
function _setmembers!(form::Formulation, constr::Constraint, members::VarMembership)
    # Compute row vector from the recorded subproblem solution
    # This adds the column to the convexity constraints automatically
    # since the setup variable is in the sp solution and it has a
    # a coefficient of 1.0 in the convexity constraints
    @logmsg LogLevel(-2) string("Setting members of constraint ", getname(form, constr))
    coef_matrix = getcoefmatrix(form)
    constr_id = getid(constr)
    @logmsg LogLevel(-4) "Members are : ", members

    for (var_id, var_coeff) in members
        # Add coef for its own variables
        var = getvar(form, var_id)
        coef_matrix[constr_id, var_id] = var_coeff
        @logmsg LogLevel(-4) string("Adding variable ", getname(form, var), " with coeff ", var_coeff)

        if getduty(var) <= MasterRepPricingVar  || getduty(var) <= MasterRepPricingSetupVar          
            # then for all columns having its own variables
            assigned_form_uid = getassignedformuid(var_id)
            spform = get_dw_pricing_sps(form.parent_formulation)[assigned_form_uid]
            for (col_id, col_coeff) in getprimalsolmatrix(spform)[var_id,:]
                @logmsg LogLevel(-4) string("Adding column ", getname(form, col_id), " with coeff ", col_coeff * var_coeff)
                coef_matrix[constr_id, col_id] = col_coeff * var_coeff
            end
        end
        
    end
    return
end

function _setmembers!(form::Formulation, constr::Constraint, members::AbstractDict{VarId, Float64})
    # Compute row vector from the recorded subproblem solution
    # This adds the column to the convexity constraints automatically
    # since the setup variable is in the sp solution and it has a
    # a coefficient of 1.0 in the convexity constraints
    @logmsg LogLevel(-2) string("Setting members of constraint ", getname(form, constr))
    coef_matrix = getcoefmatrix(form)
    constr_id = getid(constr)
    @logmsg LogLevel(-4) "Members are : ", members

    for (var_id, var_coeff) in members
        # Add coef for its own variables
        var = getvar(form, var_id)
        coef_matrix[constr_id, var_id] = var_coeff
        @logmsg LogLevel(-4) string("Adding variable ", getname(form, var), " with coeff ", var_coeff)

        if getduty(var) <= MasterRepPricingVar  || getduty(var) <= MasterRepPricingSetupVar          
            # then for all columns having its own variables
            assigned_form_uid = getassignedformuid(var_id)
            spform = get_dw_pricing_sps(form.parent_formulation)[assigned_form_uid]
            for (col_id, col_coeff) in getprimalsolmatrix(spform)[var_id,:]
                @logmsg LogLevel(-4) string("Adding column ", getname(form, col_id), " with coeff ", col_coeff * var_coeff)
                coef_matrix[constr_id, col_id] = col_coeff * var_coeff
            end
        end
        
    end
    return
end

function register_objective_sense!(form::Formulation, min::Bool)
    if min
        form.obj_sense = MinSense
    else
        form.obj_sense = MaxSense
    end
    return
end

function remove_from_optimizer!(ids::Set{Id{T}}, form::Formulation) where {
    T <: AbstractVarConstr}
    for id in ids
        vc = getelem(form, id)
        @logmsg LogLevel(-3) string("Removing varconstr of name ", getname(form, vc))
        remove_from_optimizer!(form.optimizer, vc)
    end
    return
end

function computesolvalue(form::Formulation, sol_vec::AbstractDict{Id{Variable}, Float64}) 
    val = sum(getperenecost(form, var_id) * value for (var_id, value) in sol_vec)
    return val
end


function computesolvalue(form::Formulation, sol::PrimalSolution{S}) where {S<:Coluna.AbstractSense}
    val = sum(getperenecost(form, var_id) * value for (var_id, value) in sol)
    return val
end

function computesolvalue(form::Formulation, sol_vec::AbstractDict{Id{Constraint}, Float64}) 
    val = sum(getperenerhs(form, getconstr(form, constr_id)) * value for (constr_id, value) in sol_vec)
    return val 
end

function computesolvalue(form::Formulation, sol::DualSolution{S}) where {S<:Coluna.AbstractSense}
    val = sum(getperenerhs(form, getconstr(form, constr_id)) * value for (constr_id, value) in sol)
    return val
end

function resetsolvalue!(form::Formulation, sol::DualSolution{S}) where {S<:Coluna.AbstractSense}
    val = computesolvalue(form, sol)
    setvalue!(sol, val)
    return val
end

function computereducedcost(form::Formulation, var_id::Id{Variable}, dualsol::DualSolution{S})  where {S<:Coluna.AbstractSense}
    var = getvar(form, var_id)
    rc = getperenecost(form, var)
    coefficient_matrix = getcoefmatrix(form)
    sign = 1
    if getobjsense(form) == MinSense
        sign = -1
    end
    for (constr_id, dual_val) in dualsol
        coeff = coefficient_matrix[constr_id, var_id]
        rc += sign * dual_val * coeff
    end
    return rc
end

function computereducedrhs(form::Formulation, constr_id::Id{Constraint}, primalsol::PrimalSolution{S})  where {S<:Coluna.AbstractSense}
    constr = getconstr(form,constr_id)
    crhs = getperenerhs(form, constr)
    coefficient_matrix = getcoefmatrix(form)
    for (var_id, primal_val) in primalsol
        coeff = coefficient_matrix[constr_id, var_id]
        crhs -= primal_val * coeff
    end
    return crhs
end

"Calls optimization routine for `Formulation` `form`."
function optimize!(form::Formulation)
    @logmsg LogLevel(-1) string("Optimizing formulation ", getuid(form))
    @logmsg LogLevel(-3) form
    res = optimize!(form, getoptimizer(form))
    @logmsg LogLevel(-2) begin 
        string("Optimization finished with result:")
        print(form, res)
    end
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

function _show_obj_fun(io::IO, form::Formulation)
    print(io, getobjsense(form), " ")
    vars = filter(
        vc -> getcurisactive(form,vc),
        getvars(form))
    ids = sort!(collect(keys(vars)), by = getsortuid)
    for id in ids
        name = getname(form, vars[id])
        cost = getcurcost(form, id)
        op = (cost < 0.0) ? "-" : "+" 
        print(io, op, " ", abs(cost), " ", name, " ")
    end
    println(io, " ")
    return
end

function _show_constraint(io::IO, form::Formulation, constrid::ConstrId)
    constr = getconstr(form, constrid)
    print(io, getname(form, constr), " : ")
    for (varid, coeff) in getcoefmatrix(form)[constrid, :]
        name = getname(form, varid)
        op = (coeff < 0.0) ? "-" : "+"
        print(io, op, " ", abs(coeff), " ", name, " ")
    end
    op = "<="
    if getcursense(form, constr) == Equal
        op = "=="
    elseif getcursense(form, constr) == Greater
        op = ">="
    end
    print(io, " ", op, " ", getcurrhs(form, constr))
    println(io, " (", getduty(constr), getid(constr), " | ", getcurisexplicit(form, constr) ,")")
    return
end

function _show_constraints(io::IO , form::Formulation)
    constrs = getconstrs(form)
    ids = sort!(collect(keys(constrs)), by = getsortuid)
    for constr_id in ids
        if getcurisactive(form, constr_id)
            _show_constraint(io, form, constr_id)
        end
    end
    return
end

function _show_variable(io::IO, form::Formulation, var::Variable)
    name = getname(form, var)
    lb = getcurlb(form, var)
    ub = getcurub(form, var)
    t = getcurkind(form, var)
    d = getduty(var)
    e = getcurisexplicit(form,var)
    println(io, lb, " <= ", name, " <= ", ub, " (", t, " | ", d , " | ", e, ")")
end

function _show_variables(io::IO, form::Formulation)
    vars = getvars(form)
    ids = sort!(collect(keys(vars)), by = getsortuid)
    for id in ids
        _show_variable(io, form, vars[id])
    end
end

function Base.show(io::IO, form::Formulation)
    println(io, "Formulation id = ", getuid(form))
    _show_obj_fun(io, form)
    _show_constraints(io, form)
    _show_variables(io, form)
    return
end

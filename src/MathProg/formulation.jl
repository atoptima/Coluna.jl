mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::Int
    var_counter::Int
    constr_counter::Int
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master
    optimizers::Vector{AbstractOptimizer}
    manager::FormulationManager
    obj_sense::Type{<:Coluna.AbstractSense}
    buffer::FormulationBuffer
    storage::Storage
end


"""
`Formulation` stores a mixed-integer linear program.

    create_formulation!(
        env::Coluna.Env,
        duty::Type{<:AbstractFormDuty};
        parent_formulation = nothing,
        obj_sense::Type{<:Coluna.AbstractSense} = MinSense
    )

Create a new formulation in the Coluna's environment `env` with duty `duty`,
parent formulation `parent_formulation`, and objective sense `obj_sense`.
"""
function create_formulation!(
    env::Coluna.Env,
    duty::Type{<:AbstractFormDuty};
    parent_formulation = nothing,
    obj_sense::Type{<:Coluna.AbstractSense} = MinSense
)
    if env.form_counter >= MAX_NB_FORMULATIONS
        error("Maximum number of formulations reached.")
    end
    return Formulation{duty}(
        env.form_counter += 1, 0, 0, parent_formulation, AbstractOptimizer[], 
        FormulationManager(), obj_sense, FormulationBuffer(), Storage()
    )
end

# methods of the AbstractModel interface

ColunaBase.getstorage(form::Formulation) = form.storage

# methods specific to Formulation

"""
    haskey(formulation, id) -> Bool

Return `true` if `formulation` has a variable or a constraint with given `id`.
"""
haskey(form::Formulation, id::VarId) = haskey(form.manager.vars, id)
haskey(form::Formulation, id::ConstrId) = haskey(form.manager.constrs, id)

"""
    getvar(formulation, varid) -> Variable

Return the variable with given `varid` that belongs to `formulation`.
"""
getvar(form::Formulation, id::VarId) = get(form.manager.vars, id, nothing)

"""
    getconstr(formulation, constrid) -> Constraint

Return the constraint with given `constrid` that belongs to `formulation`.
"""
getconstr(form::Formulation, id::ConstrId) = get(form.manager.constrs, id, nothing)

"""
    getvars(formulation) -> Dict{VarId, Variable}

Return all variables in `formulation`.
"""
getvars(form::Formulation) = form.manager.vars

"""
    getconstrs(formulation) -> Dict{ConstrId, Constraint}

Return all constraints in `formulation`.
"""
getconstrs(form::Formulation) = form.manager.constrs

getobjconst(form::Formulation) = form.manager.objective_constant
function setobjconst!(form::Formulation, val::Float64)
    form.manager.objective_constant = val
    form.buffer.changed_obj_const = true
    return
end

"Returns the representation of the coefficient matrix stored in the formulation manager."
getcoefmatrix(form::Formulation) = form.manager.coefficients
getprimalsolmatrix(form::Formulation) = form.manager.primal_sols
getprimalsolcosts(form::Formulation) = form.manager.primal_sol_costs
getdualsolmatrix(form::Formulation) = form.manager.dual_sols
getdualsolrhss(form::Formulation) = form.manager.dual_sol_rhss

"Returns the `uid` of `Formulation` `form`."
getuid(form::Formulation) = form.uid

"Returns the objective function sense of `Formulation` `form`."
getobjsense(form::Formulation) = form.obj_sense

"Returns the `AbstractOptimizer` of `Formulation` `form`."
function getoptimizer(form::Formulation, id::Int)
    if id <= 0 && id > length(form.optimizers)
        return NoOptimizer()
    end
    return form.optimizers[id]
end
getoptimizers(form::Formulation) = form.optimizers

getelem(form::Formulation, id::VarId) = getvar(form, id)
getelem(form::Formulation, id::ConstrId) = getconstr(form, id)

generatevarid(duty::Duty{Variable}, form::Formulation) = VarId(duty, form.var_counter += 1, getuid(form), -1)
generatevarid(
    duty::Duty{Variable}, form::Formulation, custom_family_id::Int
) = VarId(duty, form.var_counter += 1, getuid(form), custom_family_id)
generateconstrid(duty::Duty{Constraint}, form::Formulation) = ConstrId(duty, form.constr_counter += 1, getuid(form), -1)

getmaster(form::Formulation{<:AbstractSpDuty}) = form.parent_formulation
getreformulation(form::Formulation{<:AbstractMasterDuty}) = form.parent_formulation
getreformulation(form::Formulation{<:AbstractSpDuty}) = getmaster(form).parent_formulation

getstoragedict(form::Formulation) = form.storage.units

_reset_buffer!(form::Formulation) = form.buffer = FormulationBuffer()

"""
    set_matrix_coeff!(form::Formulation, v_id::Id{Variable}, c_id::Id{Constraint}, new_coeff::Float64)

Buffers the matrix modification in `form.buffer` to be sent to the optimizers right before next call to optimize!.
"""
set_matrix_coeff!(
    form::Formulation, varid::VarId, constrid::ConstrId, new_coeff::Float64
) = set_matrix_coeff!(form.buffer, varid, constrid, new_coeff)

"""
    setvar!(
        formulation, name, duty;
        cost = 0.0,
        lb = 0.0,
        ub = Inf,
        kind = Continuous,
        is_active = true,
        is_explicit = true,
        members = nothing,
    )

Create a new variable that has name `name` and duty `duty` in the formulation `formulation`.

Following keyword arguments allow the user to set additional information about the new variable :
 - `cost`: cost of the variable in the objective function
 - `lb`: lower bound of the variable
 - `ub`: upper bound of the variable
 - `kind`: kind which can be `Continuous`, `Binary` or `Integ`
 - `is_active`: `true` if the variable is used in the formulation, `false` otherwise
 - `is_explicit`: `true` if the variable takes part to the formulation, `false` otherwise (e.g. a variable used as a shortcut for calculation purposes)
 - `members`: a dictionary `Dict{ConstrId, Float64}` that contains the coefficients of the new variable in the constraints of the formulation (default coefficient is 0).
"""
function setvar!(
    form::Formulation,
    name::String,
    duty::Duty{Variable};
    cost::Float64 = 0.0,
    lb::Float64 = 0.0,
    ub::Float64 = Inf,
    kind::VarKind = Continuous,
    inc_val::Float64 = 0.0,
    is_active::Bool = true,
    is_explicit::Bool = true,
    moi_index::MoiVarIndex = MoiVarIndex(),
    members::Union{ConstrMembership,Nothing} = nothing,
    custom_data::Union{Nothing, AbstractCustomData} = nothing,
    id = generatevarid(duty, form),
    branching_priority::Float64 = 1.0
)
    if kind == Binary
        lb = (lb < 0.0) ? 0.0 : lb
        ub = (ub > 1.0) ? 1.0 : ub
    end
    if getduty(id) != duty
        id = VarId(duty, id, -1)
    end
    if custom_data !== nothing
        id = VarId(duty, id, form.manager.custom_families_id[typeof(custom_data)])
    end
    v_data = VarData(cost, lb, ub, kind, inc_val, is_active, is_explicit)
    var = Variable(
        id, name;
        var_data = v_data,
        moi_index = moi_index,
        custom_data = custom_data,
        branching_priority = branching_priority
    )
    _addvar!(form, var)
    _setmembers!(form, var, members)
    return var
end

function _addvar!(form::Formulation, var::Variable)
    _addvar!(form.manager, var)
    if isexplicit(form, var)
        add!(form.buffer, getid(var))
    end
    return
end

function _addprimalsol!(form::Formulation, sol_id::VarId, sol::PrimalSolution, cost::Float64)
    for (var_id, var_val) in sol
        if getduty(var_id) <= DwSpSetupVar || getduty(var_id) <= DwSpPricingVar
            form.manager.primal_sols[var_id, sol_id] = var_val
        end
    end
    form.manager.primal_sol_costs[sol_id] = cost
    if sol.custom_data !== nothing
        form.manager.primal_sols_custom_data[sol_id] = sol.custom_data
    end
    return sol_id
end

function setprimalsol!(form::Formulation, new_primal_sol::PrimalSolution)::Tuple{Bool,VarId}
    primal_sols = getprimalsolmatrix(form)
    primal_sol_costs = getprimalsolcosts(form)

    # compute original cost of the column
    new_cost = 0.0
    for (var_id, var_val) in new_primal_sol
        new_cost += getperencost(form, var_id) * var_val
    end

    # look for an identical column
    for (cur_sol_id, cur_cost) in primal_sol_costs
        cur_primal_sol = primal_sols[:, cur_sol_id]
        if isapprox(new_cost, cur_cost) && getsol(new_primal_sol) == cur_primal_sol
            return (false, cur_sol_id)
        end
    end

    # no identical column, we insert a new column
    custom_family_id = get(
        form.parent_formulation.manager.custom_families_id, typeof(new_primal_sol.custom_data), -1
    )
    new_sol_id = generatevarid(DwSpPrimalSol, form, custom_family_id)
    _addprimalsol!(form, new_sol_id, new_primal_sol, new_cost)
    return (true, new_sol_id)
end

function _adddualsol!(form::Formulation, dualsol::DualSolution, dualsol_id::ConstrId)
    rhs = 0.0
    for (constrid, constrval) in dualsol
        rhs += getperenrhs(form, constrid) * constrval
        if getduty(constrid) <= AbstractBendSpMasterConstr
            form.manager.dual_sols[constrid, dualsol_id] = constrval
        end
    end
    form.manager.dual_sol_rhss[dualsol_id] = rhs
    return dualsol_id
end

function setdualsol!(form::Formulation, new_dual_sol::DualSolution)::Tuple{Bool,ConstrId}
    ### check if dualsol exists  take place here along the coeff update
    dual_sols = getdualsolmatrix(form)
    dual_sol_rhss = getdualsolrhss(form)

    for (cur_sol_id, cur_rhs) in dual_sol_rhss
        factor = 1.0
        if getvalue(new_dual_sol) != cur_rhs
            factor = cur_rhs / getvalue(new_dual_sol)
        end

        # TODO : implement broadcasting for PMA in DynamicSparseArrays
        is_identical = true
        cur_dual_sol = dual_sols[cur_sol_id, :]
        for (constr_id, constr_val) in cur_dual_sol
            if factor * getsol(new_dual_sol)[constr_id] != constr_val
                is_identical = false
                break
            end
        end

        for (constr_id, constr_val) in getsol(new_dual_sol)
            if factor * constr_val != cur_dual_sol[constr_id]
                is_identical = false
                break
            end
        end

        is_identical && return (false, cur_sol_id)
    end

    ### else not identical to any existing dual sol
    new_dual_sol_id = generateconstrid(BendSpDualSol, form)
    _adddualsol!(form, new_dual_sol, new_dual_sol_id)
    return (true, new_dual_sol_id)
end

function setcol_from_sp_primalsol!(
    masterform::Formulation, spform::Formulation, sol_id::VarId, name::String,
    duty::Duty{Variable}; lb::Float64 = 0.0, ub::Float64 = Inf, kind::VarKind = Continuous,
    inc_val::Float64 = 0.0, is_active::Bool = true, is_explicit::Bool = true,
    moi_index::MoiVarIndex = MoiVarIndex(), custom_data::Union{Nothing, AbstractCustomData} = nothing
)
    cost = getprimalsolcosts(spform)[sol_id]
    master_coef_matrix = getcoefmatrix(masterform)
    sp_sol = getprimalsolmatrix(spform)[:,sol_id]
    members = ConstrMembership()

    for (sp_var_id, sp_var_val) in sp_sol
        for (master_constrid, sp_var_coef) in @view master_coef_matrix[:,sp_var_id]
            val = get(members, master_constrid, 0.0)
            members[master_constrid] = val + sp_var_val * sp_var_coef
        end
    end

    mast_col = setvar!(
        masterform, name, duty,
        cost = cost,
        lb = lb,
        ub = ub,
        kind = kind,
        inc_val = inc_val,
        is_active = is_active,
        is_explicit = is_explicit,
        moi_index = moi_index,
        members = members,
        id = sol_id,
        custom_data = get(spform.manager.primal_sols_custom_data, sol_id, nothing)
    )
    return mast_col
end

function setcut_from_sp_dualsol!(
    masterform::Formulation,
    spform::Formulation,
    dual_sol_id::ConstrId,
    name::String,
    duty::Duty{Constraint};
    kind::ConstrKind = Essential,
    sense::ConstrSense = Greater,
    inc_val::Float64 = -1.0,
    is_active::Bool = true,
    is_explicit::Bool = true,
    moi_index::MoiConstrIndex = MoiConstrIndex()
)
    rhs = getdualsolrhss(spform)[dual_sol_id]
    benders_cut_id = Id{Constraint}(duty, dual_sol_id)
    benders_cut_data = ConstrData(
        rhs, Essential, sense, inc_val, is_active, is_explicit
    )
    benders_cut = Constraint(
        benders_cut_id, name;
        constr_data = benders_cut_data,
        moi_index = moi_index
    )
    master_coef_matrix = getcoefmatrix(masterform)
    sp_coef_matrix = getcoefmatrix(spform)
    sp_dual_sol = getdualsolmatrix(spform)[:,dual_sol_id]

    for (ds_constrid, ds_constr_val) in sp_dual_sol
        ds_constr = getconstr(spform, ds_constrid)
        if getduty(ds_constrid) <= AbstractBendSpMasterConstr
            for (master_var_id, sp_constr_coef) in @view sp_coef_matrix[ds_constrid,:]
                var = getvar(spform, master_var_id)
                if getduty(master_var_id) <= AbstractBendSpSlackMastVar
                    master_coef_matrix[benders_cut_id, master_var_id] += ds_constr_val * sp_constr_coef
                end
            end
        end
    end
    _addconstr!(masterform.manager, benders_cut)
    if isexplicit(masterform, benders_cut)
        add!(masterform.buffer, getid(benders_cut))
    end
    return benders_cut
end

"""
    setconstr!(
        formulation, name, duty;
        rhs = 0.0,
        kind = Essential,
        sense = Greater,
        is_active = true,
        is_explicit = true,
        members = nothing,
        loc_art_var_abs_cost = 0.0,
    )

Create a new constraint that has name `name` and duty `duty` in the formulation `formulation`.
Following keyword arguments allow the user to set additional information about the new constraint :
 - `rhs`: right-hand side of the constraint
 - `kind`: kind which can be `Essential` or `Facultative`
 - `sense`: sense which can be `Greater`, `Less`, or `Equal`
 - `is_active`: `true` if the constraint is used in the formulation, `false` otherwise
 - `is_explicit`: `true` if the constraint structures the formulation, `false` otherwise
 - `members`:  a dictionary `Dict{VarId, Float64}` that contains the coefficients of the variables of the formulation in the new constraint (default coefficient is 0).
 - `loc_art_var_abs_cost`: absolute cost of the artificial variables of the constraint
"""
function setconstr!(
    form::Formulation,
    name::String,
    duty::Duty{Constraint};
    rhs::Float64 = 0.0,
    kind::ConstrKind = Essential,
    sense::ConstrSense = Greater,
    inc_val::Float64 = 0.0,
    is_active::Bool = true,
    is_explicit::Bool = true,
    moi_index::MoiConstrIndex = MoiConstrIndex(),
    members = nothing, # todo Union{AbstractDict{VarId,Float64},Nothing}
    loc_art_var_abs_cost::Float64 = 0.0,
    custom_data::Union{Nothing, AbstractCustomData} = nothing,
    id = generateconstrid(duty, form)
)
    if getduty(id) != duty
        id = ConstrId(duty, id, -1)
    end
    if custom_data !== nothing
        id = ConstrId(
            duty, id, custom_family_id = form.manager.custom_families_id[typeof(custom_data)]
        )
    end
    c_data = ConstrData(rhs, kind, sense,  inc_val, is_active, is_explicit)
    constr = Constraint(id, name; constr_data = c_data, moi_index = moi_index, custom_data = custom_data)

    _setmembers!(form, constr, members)
    _addconstr!(form.manager, constr)
    if loc_art_var_abs_cost != 0.0
        _addlocalartvar!(form, constr, loc_art_var_abs_cost)
    end
    if isexplicit(form, constr)
        add!(form.buffer, getid(constr))
    end
    return constr
end

function set_robust_constr_generator!(form::Formulation, kind::ConstrKind, alg::Function)
    constrgen = RobustConstraintsGenerator(0, kind, alg)
    push!(form.manager.robust_constr_generators, constrgen)
    return
end

get_robust_constr_generators(form::Formulation) = form.manager.robust_constr_generators

function _addlocalartvar!(form::Formulation, constr::Constraint, abs_cost::Float64)
    matrix = getcoefmatrix(form)
    cost = (getobjsense(form) == MinSense ? 1.0 : -1.0) * abs_cost
    constrid = getid(constr)
    constrname = getname(form, constr)
    constrsense = getperensense(form, constr)
    if constrsense == Equal
        name1 = string("local_art_of_", constrname, "1")
        name2 = string("local_art_of_", constrname, "2")
        var1 = setvar!(
            form, name1, MasterArtVar; cost = cost, lb = 0.0, ub = Inf, kind = Continuous
        )
        var2 = setvar!(
            form, name1, MasterArtVar; cost = cost, lb = 0.0, ub = Inf, kind = Continuous
        )
        push!(constr.art_var_ids, getid(var1))
        push!(constr.art_var_ids, getid(var2))
        matrix[constrid, getid(var1)] = 1.0
        matrix[constrid, getid(var2)] = -1.0
    else
        name = string("local_art_of_", constrname)
        var = setvar!(
            form, name, MasterArtVar; cost = cost, lb = 0.0, ub = Inf, kind = Continuous
        )
        push!(constr.art_var_ids, getid(var))
        if constrsense == Greater
            matrix[constrid, getid(var)] = 1.0
        elseif constrsense == Less
            matrix[constrid, getid(var)] = -1.0
        end
    end
    return
end

function enforce_integrality!(form::Formulation)
    @logmsg LogLevel(-1) string("Enforcing integrality of formulation ", getuid(form))
    for (varid, var) in getvars(form)
        !iscuractive(form, varid) && continue
        !isexplicit(form, varid) && continue
        getcurkind(form, varid) == Integ && continue
        getcurkind(form, varid) == Binary && continue
        if getduty(varid) <= MasterCol || getperenkind(form, varid) != Continuous
            @logmsg LogLevel(-3) string("Setting kind of var ", getname(form, var), " to Integer")
            setcurkind!(form, varid, Integ)
        end
    end
    return
end

function relax_integrality!(form::Formulation) # TODO remove : should be in Algorithm
    @logmsg LogLevel(-1) string("Relaxing integrality of formulation ", getuid(form))
    for (varid, var) in getvars(form)
        !iscuractive(form, varid) && continue
        !isexplicit(form, varid) && continue
        getcurkind(form, var) == Continuous && continue
        @logmsg LogLevel(-3) string("Setting kind of var ", getname(form, var), " to continuous")
        setcurkind!(form, varid, Continuous)
    end
    return
end

_setrobustmembers!(::Formulation, ::Variable, ::Nothing) = nothing
function _setrobustmembers!(form::Formulation, var::Variable, members::ConstrMembership)
    coef_matrix = getcoefmatrix(form)
    varid = getid(var)
    for (constrid, constr_coeff) in members
        coef_matrix[constrid, varid] = constr_coeff
    end
    return
end

_setrobustmembers!(::Formulation, ::Constraint, ::Nothing) = nothing
function _setrobustmembers!(form::Formulation, constr::Constraint, members::VarMembership)
    # Compute row vector from the recorded subproblem solution
    # This adds the column to the convexity constraints automatically
    # since the setup variable is in the sp solution and it has a
    # a coefficient of 1.0 in the convexity constraints
    coef_matrix = getcoefmatrix(form)
    constrid = getid(constr)

    for (varid, var_coeff) in members
        # Add coef for its own variables
        coef_matrix[constrid, varid] = var_coeff

        if getduty(varid) <= MasterRepPricingVar  || getduty(varid) <= MasterRepPricingSetupVar
            # then for all columns having its own variables
            assigned_form_uid = getassignedformuid(varid)
            spform = get_dw_pricing_sps(form.parent_formulation)[assigned_form_uid]
            for (col_id, col_coeff) in @view getprimalsolmatrix(spform)[varid,:]
                coef_matrix[constrid, col_id] += col_coeff * var_coeff
            end
        end
    end
    return
end

# interface ==> move ?
function computecoeff(::Variable, var_custom_data, ::Constraint, constr_custom_data)
    error("computecoeff not defined for variable with $(typeof(var_custom_data)) & constraint with $(typeof(constr_custom_data)).")
end

function _computenonrobustmembers(form::Formulation, var::Variable)
    coef_matrix = getcoefmatrix(form)
    for (constrid, constr) in getconstrs(form) # TODO : improve because we loop over all constraints
        if constrid.custom_family_id !== -1
            coeff = computecoeff(var, var.custom_data, constr, constr.custom_data)
            if coeff !== 0
                coef_matrix[constrid, getid(var)] = coeff
            end
        end
    end
    return
end

function _computenonrobustmembers(form::Formulation, constr::Constraint)
    coef_matrix = getcoefmatrix(form)
    for (varid, var) in getvars(form) # TODO : improve because we loop over all variables
        if varid.custom_family_id !== -1
            coeff = computecoeff(var, var.custom_data, constr, constr.custom_data)
            if coeff !== 0
                coef_matrix[getid(constr), varid] = coeff
            end
        end
    end
    return
end

function _setmembers!(form::Formulation, varconstr, members)
    _setrobustmembers!(form, varconstr, members)
    if getid(varconstr).custom_family_id !== -1
        _computenonrobustmembers(form, varconstr)
    end
    return
end

function set_objective_sense!(form::Formulation, min::Bool)
    if min
        form.obj_sense = MinSense
    else
        form.obj_sense = MaxSense
    end
    return
end

function computesolvalue(form::Formulation, sol_vec::AbstractDict{Id{Variable}, Float64})
    val = sum(getperencost(form, varid) * value for (varid, value) in sol_vec)
    return val
end

function computereducedcost(form::Formulation, varid::Id{Variable}, dualsol::DualSolution)
    redcost = getperencost(form, varid)
    coefficient_matrix = getcoefmatrix(form)
    sign = 1
    if getobjsense(form) == MinSense
        sign = -1
    end
    for (constrid, dual_val) in dualsol
        coeff = coefficient_matrix[constrid, varid]
        redcost += sign * dual_val * coeff
    end
    return redcost
end

function computereducedrhs(form::Formulation, constrid::Id{Constraint}, primalsol::PrimalSolution)
    constrrhs = getperenrhs(form,constrid)
    coefficient_matrix = getcoefmatrix(form)
    for (varid, primal_val) in primalsol
        coeff = coefficient_matrix[constrid, varid]
        constrrhs -= primal_val * coeff
    end
    return constrrhs
end

function constraint_primal(primalsol::PrimalSolution, constrid::ConstrId)
    val = 0.0
    for (varid, coeff) in @view getcoefmatrix(primalsol.model)[constrid, :]
        val += coeff * primalsol[varid]
    end
    return val
end

function push_optimizer!(form::Formulation, builder::Function)
    opt = builder()
    push!(form.optimizers, opt)
    initialize_optimizer!(opt, form)
    return
end

function _show_obj_fun(io::IO, form::Formulation)
    print(io, getobjsense(form), " ")
    vars = filter(v -> isexplicit(form, v.first), getvars(form))
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
    println(io, " (", getduty(constrid), constrid, " | ", isexplicit(form, constr) ,")")
    return
end

function _show_constraints(io::IO , form::Formulation)
    constrs = getconstrs(form)
    ids = sort!(collect(keys(constrs)), by = getsortuid)
    for constr_id in ids
        if iscuractive(form, constr_id)
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
    d = getduty(getid(var))
    e = isexplicit(form, var)
    println(io, lb, " <= ", name, " <= ", ub, " (", t, " | ", d , " | ", e, ")")
end

function _show_variables(io::IO, form::Formulation)
    vars = getvars(form)
    ids = sort!(collect(keys(vars)), by = getsortuid)
    for varid in ids
        _show_variable(io, form, vars[varid])
    end
end

function Base.show(io::IO, form::Formulation{Duty}) where {Duty <: AbstractFormDuty}
    compact = get(io, :compact, false)
    if compact
        dutystring = remove_until_last_point(string(Duty))
        print(io, "form. ", dutystring, " with id=", getuid(form))
    else
        println(io, "Formulation id = ", getuid(form))
        _show_obj_fun(io, form)
        _show_constraints(io, form)
        _show_variables(io, form)
    end
    return
end

function addcustomvars!(form::Formulation, type::DataType)
    haskey(form.manager.custom_families_id, type) && return
    form.manager.custom_families_id[type] = length(form.manager.custom_families_id)
    return
end

function addcustomconstrs!(form::Formulation, type::DataType)
    haskey(form.manager.custom_families_id, type) && return
    form.manager.custom_families_id[type] = length(form.manager.custom_families_id)
    return
end

# function getspsol(master::Formulation{DwMaster}, col_id::VarId)
#     !(getduty(col_id) <= MasterCol) && return

#     spvars = Vector{VarId}()
#     spvals = Vector{Float64}()
#     cost = 0.0

#     spuid = getoriginformuid(col_id)
#     spform = get_dw_pricing_sps(master.parent_formulation)[spuid]
#     for (repid, repval) in @view getprimalsolmatrix(spform)[:, col_id]
#         if getduty(repid) <= DwSpPricingVar || getduty(repid) <= DwSpSetupVar
#             mastrepid = getid(getvar(master, repid))
#             push!(spvars, mastrepid)
#             push!(spvals, repval)
#             cost += getcurcost(master, mastrepid)
#         end
#     end

#     return PrimalSolution(spform, spvars, spvals, cost, FEASIBLE_SOL)
# end

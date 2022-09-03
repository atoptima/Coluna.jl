mutable struct Formulation{Duty <: AbstractFormDuty}  <: AbstractFormulation
    uid::Int
    parent_formulation::Union{AbstractFormulation, Nothing} # master for sp, reformulation for master
    optimizers::Vector{AbstractOptimizer}
    manager::FormulationManager
    obj_sense::Type{<:Coluna.AbstractSense}
    buffer::FormulationBuffer
    storage::Union{Nothing,NewStorage}
    duty_data::Duty
    env::Env{VarId}
end

"""
A `Formulation` stores a mixed-integer linear program.

    create_formulation!(
        env::Coluna.Env,
        duty::AbstractFormDuty;
        parent_formulation = nothing,
        obj_sense::Type{<:Coluna.AbstractSense} = MinSense
    )

Creates a new formulation in the Coluna's environment `env`.
Arguments are `duty` that contains specific information related to the duty of
the formulation, `parent_formulation` that is the parent formulation (master for a subproblem, 
reformulation for a master, `nothing` by default), and `obj_sense` the sense of the objective 
function (`MinSense` or `MaxSense`).
"""
function create_formulation!(
    env::Env{VarId},
    duty::AbstractFormDuty;
    parent_formulation = nothing,
    obj_sense::Type{<:Coluna.AbstractSense} = MinSense
)
    if env.form_counter >= MAX_NB_FORMULATIONS
        error("Maximum number of formulations reached.")
    end

    buffer = FormulationBuffer{VarId,Variable,ConstrId,Constraint}()
    form = Formulation(
        env.form_counter += 1, parent_formulation, AbstractOptimizer[], 
        FormulationManager(buffer, custom_families_id = env.custom_families_id), obj_sense,
        buffer, nothing, duty, env
    )
    storage = NewStorage(form)
    form.storage = storage
    return form
end

# methods of the AbstractModel interface

ClB.getuid(form::Formulation) = form.uid
ClB.getstorage(form::Formulation) = form.storage

# methods specific to Formulation

"""
    haskey(formulation, id) -> Bool

Returns `true` if `formulation` has a variable or a constraint with given `id`.
"""
haskey(form::Formulation, id::VarId) = haskey(form.manager.vars, id)
haskey(form::Formulation, id::ConstrId) = haskey(form.manager.constrs, id) || haskey(form.manager.single_var_constrs, id)

"""
    getvar(formulation, varid) -> Variable

Returns the variable with given `varid` that belongs to `formulation`.
"""
getvar(form::Formulation, id::VarId) = get(form.manager.vars, id, nothing)

"""
    getconstr(formulation, constrid) -> Constraint

Returns the constraint with given `constrid` that belongs to `formulation`.
"""
getconstr(form::Formulation, id::ConstrId) = get(form.manager.constrs, id, nothing)

"""
    getvars(formulation) -> Dict{VarId, Variable}

Returns all variables in `formulation`.
"""
getvars(form::Formulation) = form.manager.vars

"""
    getconstrs(formulation) -> Dict{ConstrId, Constraint}

Returns all constraints in `formulation`.
"""
getconstrs(form::Formulation) = form.manager.constrs

"Returns objective constant of the formulation."
getobjconst(form::Formulation) = form.manager.objective_constant

"Sets objective constant of the formulation."
function setobjconst!(form::Formulation, val::Float64)
    form.manager.objective_constant = val
    return
end

"Returns the representation of the coefficient matrix stored in the formulation manager."
getcoefmatrix(form::Formulation) = form.manager.coefficients

getdualsolmatrix(form::Formulation) = form.manager.dual_sols
getdualsolrhss(form::Formulation) = form.manager.dual_sol_rhss

"Returns the objective function sense of a formulation."
getobjsense(form::Formulation) = form.obj_sense

"Returns the optimizer of a formulation at a given position."
function getoptimizer(form::Formulation, pos::Int)
    if pos <= 0 && pos > length(form.optimizers)
        return NoOptimizer()
    end
    return form.optimizers[pos]
end

"Returns all the optimizers of a formulation."
getoptimizers(form::Formulation) = form.optimizers

"""
    getelem(form, varid) -> Variable
    getelem(form, constrid) -> Constraint

Return the element of formulation `form` that has a given id.
"""
getelem(form::Formulation, id::VarId) = getvar(form, id)
getelem(form::Formulation, id::ConstrId) = getconstr(form, id)

getmaster(form::Formulation{<:AbstractSpDuty}) = form.parent_formulation
getreformulation(form::Formulation{<:AbstractMasterDuty}) = form.parent_formulation
getreformulation(form::Formulation{<:AbstractSpDuty}) = getmaster(form).parent_formulation

getstoragedict(form::Formulation) = form.storage.units

"""
    setvar!(
        formulation, name, duty;
        cost = 0.0,
        lb = -Inf,
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
    # Perennial state of the variable
    cost::Float64 = 0.0,
    lb::Float64 = -Inf,
    ub::Float64 = Inf,
    kind::VarKind = Continuous,
    inc_val::Float64 = 0.0,
    is_active::Bool = true,
    is_explicit::Bool = true,
    branching_priority::Float64 = 1.0,
    # The moi index of the variable contains all the information to change its
    # state in the formulation stores in the underlying MOI solver.
    moi_index::MoiVarIndex = MoiVarIndex(),
    # Coefficient of the variable in the constraints of the `form` formulation.
    members::Union{ConstrMembership,Nothing} = nothing,
    # Custom representation of the variable (advanced use).
    custom_data::Union{Nothing, BD.AbstractCustomData} = nothing,
    # Default id of the variable.
    id = VarId(duty, form.env.var_counter += 1, getuid(form)),
    # The formulation from which the variable is generated.
    origin::Union{Nothing,Formulation} = nothing,
    # By default, the name of the variable is `name`. However, when you do column
    # generation, you may want to identify each variable without having to generate
    # a new name for each variable. If you set this attribute to `true`, the name of 
    # the variable will be `name_uid`.
    id_as_name_suffix = false,
)
    # TODO: we should have a dedicated procedure for preprocessing.
    if kind == Binary
        lb = lb < 0.0 ? 0.0 : lb
        ub = ub > 1.0 ? 1.0 : ub
    end

    origin_form_uid = origin !== nothing ? FormId(getuid(origin)) : nothing

    custom_family_id = if custom_data !== nothing
        Int8(form.manager.custom_families_id[typeof(custom_data)])
    else
        nothing
    end

    # When the keyword arguments of this `Id` constructor are equal to nothing, they
    # retrieve their values from `id` (see the code of the constructor in vcids.jl).
    id = VarId(
        id; duty = duty, origin_form_uid = origin_form_uid, 
        custom_family_id = custom_family_id
    )

    if id_as_name_suffix
        name = string(name, "_", getuid(id))
    end
    if isempty(name)
        name = string("v_", getuid(id))
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

############################################################################################
# Methods specific to a Formulation with DwSp duty
############################################################################################

get_primal_sol_pool(form::Formulation{DwSp}) = form.duty_data.primalsols_pool
get_primal_sol_pool_hash_table(form::Formulation{DwSp}) = form.duty_data.hashtable_primalsols_pool

############################################################################################
# Pool of solutions
# We consider that the pool is a dynamic sparse matrix.
############################################################################################

# Returns nothing if there is no identical solutions in pool; the id of the
# identical solution otherwise.
function _get_same_sol_in_pool(pool_sols, pool_hashtable, sol)
    sols_with_same_members = getsolids(pool_hashtable, sol)
    for existing_sol_id in sols_with_same_members
        existing_sol = @view pool_sols[existing_sol_id,:]
        if existing_sol == sol
            return existing_sol_id
        end
    end
    return nothing
end

# We only keep variables that have certain duty in the representation of the 
# solution stored in the pool. The second argument allows us to dispatch because
# filter may change depending on the duty of the formulation.
function _sol_repr_for_pool(primal_sol::PrimalSolution, ::DwSp)
    var_ids = VarId[]
    vals = Float64[]
    for (var_id, val) in primal_sol
        if getduty(var_id) <= DwSpSetupVar || getduty(var_id) <= DwSpPricingVar
            push!(var_ids, var_id)
            push!(vals, val)
        end
    end
    return var_ids, vals
end

function initialize_solution_pool!(form::Formulation{DwSp}, initial_columns_callback::Function)
    master = getmaster(form)
    cbdata = InitialColumnsCallbackData(form, PrimalSolution[])
    initial_columns_callback(cbdata)
    for sol in cbdata.primal_solutions
        insert_column!(master, sol, "iMC")
    end
    return
end

############################################################################################
# Insertion of a column in the master
############################################################################################
# Compute all the coefficients of the column in the coefficient matrix of the
# master formulation.
function _col_members(col, master_coef_matrix)
    members = Dict{ConstrId, Float64}()
    for (sp_var_id, sp_var_val) in col
        for (master_constrid, sp_var_coef) in @view master_coef_matrix[:,sp_var_id]
            val = get(members, master_constrid, 0.0)
            members[master_constrid] = val + sp_var_val * sp_var_coef
        end
    end
    return members
end

"""
    get_column_from_pool(primal_sol)

Returns the `var_id` of the master column that represents the primal solution `primal_sol` 
to a Dantzig-Wolfe subproblem if the primal solution exists in the pool of solutions to the
subproblem; `nothing` otherwise.
"""
function get_column_from_pool(primal_sol::PrimalSolution{Formulation{DwSp}})
    spform = primal_sol.solution.model
    pool = get_primal_sol_pool(spform)
    pool_hashtable = get_primal_sol_pool_hash_table(spform)
    return _get_same_sol_in_pool(pool, pool_hashtable, primal_sol)
end

"""
    insert_column!(master_form, primal_sol, name)

Inserts the primal solution `primal_sol` to a Dantzig-Wolfe subproblem into the
master as a column.

Returns `var_id` the id of the column variable in the master formulation.

**Warning**: this methods does not check if the column already exists in the pool.
"""
function insert_column!(
    master_form::Formulation{DwMaster}, primal_sol::PrimalSolution, name::String;
    lb::Float64 = 0.0,
    ub::Float64 = Inf,
    inc_val::Float64 = 0.0,
    is_active::Bool = true,
    is_explicit::Bool = true,
    store_in_sp_pool = true
)
    spform = primal_sol.solution.model

    # Compute perennial cost of the column.
    new_col_peren_cost = mapreduce(
        ((var_id, var_val),) -> getperencost(spform, var_id) * var_val,
        +,
        primal_sol
    )

    pool = get_primal_sol_pool(spform)
    pool_hashtable = get_primal_sol_pool_hash_table(spform)
    costs_pool = spform.duty_data.costs_primalsols_pool
    custom_pool = spform.duty_data.custom_primalsols_pool

    # Compute coefficient members of the column in the matrix.
    members = _col_members(primal_sol, getcoefmatrix(master_form))

    # Insert the column in the master.
    col = setvar!(
        master_form, name, MasterCol,
        cost = new_col_peren_cost,
        lb = lb,
        ub = ub,
        kind = spform.duty_data.column_var_kind,
        inc_val = inc_val,
        is_active = is_active,
        is_explicit = is_explicit,
        moi_index = MoiVarIndex(),
        members = members,
        custom_data = primal_sol.custom_data,
        id_as_name_suffix = true,
        origin = spform
    )
    setcurkind!(master_form, col, Continuous)

    # Store the solution in the pool if asked.
    if store_in_sp_pool
        col_id = VarId(getid(col); duty = DwSpPrimalSol)
        var_ids, vals = _sol_repr_for_pool(primal_sol, spform.duty_data)
        addrow!(pool, col_id, var_ids, vals)
        costs_pool[col_id] = new_col_peren_cost
        if primal_sol.custom_data !== nothing
            custom_pool[col_id] = primal_sol.custom_data
        end
        savesolid!(pool_hashtable, col_id, primal_sol)
    end
    return getid(col)
end

############################################################################################

function _adddualsol!(form::Formulation, dualsol::DualSolution, dualsol_id::ConstrId)
    rhs = 0.0
    for (constrid, constrval) in dualsol
        rhs += getperenrhs(form, constrid) * constrval
        if getduty(constrid) <= AbstractBendSpMasterConstr
            form.manager.dual_sols[constrid, dualsol_id] = constrval
        end
    end
    for (varid, varval) in get_var_redcosts(dualsol)
        redcost, activebound = varval
        bound = activebound == LOWER ? getcurlb(form, varid) : getcurub(form, varid)
        rhs += bound * redcost
        if getduty(varid) <= AbstractBendSpMasterConstr
            form.manager.dual_sols_varbounds[varid, dualsol_id] = varval
        end
    end
    form.manager.dual_sol_rhss[dualsol_id] = rhs
    return dualsol_id
end

function setdualsol!(form::Formulation, new_dual_sol::DualSolution)::Tuple{Bool,ConstrId}
    ### check if dualsol exists  take place here along the coeff update
    dual_sols = getdualsolmatrix(form)
    dual_sols_varbounds = form.manager.dual_sols_varbounds
    dual_sol_rhss = getdualsolrhss(form)

    for (cur_sol_id, cur_rhs) in dual_sol_rhss
        factor = 1.0
        if getvalue(new_dual_sol) != cur_rhs
            factor = cur_rhs / getvalue(new_dual_sol)
        end

        # TODO : implement broadcasting for PMA in DynamicSparseArrays
        is_identical = true
        cur_dual_sol = @view dual_sols[:,cur_sol_id]
        for (constr_id, constr_val) in cur_dual_sol
            if factor * new_dual_sol.solution.sol[constr_id] != constr_val
                is_identical = false
                break
            end
        end

        cur_dual_sol_varbounds = @view dual_sols_varbounds[:,cur_sol_id]
        for (var_id, var_val) in cur_dual_sol_varbounds
            if factor * get_var_redcosts(new_dual_sol)[var_id][1] != var_val[1] || get_var_redcosts(new_dual_sol)[var_id][2] != var_val[2]
                is_identical = false
                break
            end
        end

        is_identical && return (false, cur_sol_id)
    end

    ### else not identical to any existing dual sol
    new_dual_sol_id = ConstrId(BendSpDualSol, form.env.constr_counter += 1, getuid(form))
    _adddualsol!(form, new_dual_sol, new_dual_sol_id)
    return (true, new_dual_sol_id)
end

function setcut_from_sp_dualsol!(
    masterform::Formulation{BendersMaster},
    spform::Formulation{BendersSp},
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
    objc = getobjsense(masterform) === MinSense ? 1.0 : -1.0

    rhs = objc * getdualsolrhss(spform)[dual_sol_id]
    benders_cut_id = ConstrId(dual_sol_id; duty = duty)
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

    for (constr_id, constr_val) in sp_dual_sol
        if getduty(constr_id) <= AbstractBendSpMasterConstr
            for (var_id, coef) in @view sp_coef_matrix[constr_id,:]
                master_var_id = nothing
                if getduty(var_id) <= BendSpPosSlackFirstStageVar
                    orig_var_id = get(spform.duty_data.slack_to_first_stage, var_id, nothing)
                    if orig_var_id === nothing
                        error("""
                            A subproblem first level slack variable is not mapped to a first level variable. 
                            Please open an issue at https://github.com/atoptima/Coluna.jl/issues.
                        """)
                    end
                    master_var_id = getid(getvar(masterform, orig_var_id))
                elseif getduty(var_id) <= BendSpSlackSecondStageCostVar
                    master_var_id = var_id # identity
                end

                if master_var_id !== nothing
                    master_coef_matrix[benders_cut_id, master_var_id] += objc * constr_val * coef
                end
            end
        end
    end

    # sp_dual_sol = spform.manager.dual_sols_varbounds[:,dual_sol_id]
    # for (var_id, var_val) in sp_dual_sol
    #     var_val, active_bound = var_val
    #     if getduty(var_id) <= AbstractBendSpVar
    #         orig_var_id
    #     end
    # end

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
    custom_data::Union{Nothing, BD.AbstractCustomData} = nothing,
    id = ConstrId(duty, form.env.constr_counter += 1, getuid(form))
)
    if getduty(id) != duty
        id = ConstrId(id, duty = duty)
    end
    if isempty(name)
        name = string("c_", getuid(id))
    end
    if custom_data !== nothing
        id = ConstrId(
            id, 
            custom_family_id = form.manager.custom_families_id[typeof(custom_data)]
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
            form, name2, MasterArtVar; cost = cost, lb = 0.0, ub = Inf, kind = Continuous
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

"""
    enforce_integrality!(formulation)

Set the current kind of each active & explicit variable of the formulation to its perennial kind.
"""
function enforce_integrality!(form::Formulation)
    for (_, var) in getvars(form)
        enforce = iscuractive(form, var) && isexplicit(form, var)
        enforce &= getcurkind(form, var) === Continuous
        enforce &= getperenkind(form, var) !== Continuous
        if enforce
            setcurkind!(form, var, getperenkind(form, var))
        end
    end
    return
end

"""
    relax_integrality!(formulation)

Set the current kind of each active & explicit integer or binary variable of the formulation
to continuous.
"""
function relax_integrality!(form::Formulation)
    for (_, var) in getvars(form)
        relax = iscuractive(form, var) && isexplicit(form, var)
        relax &= getcurkind(form, var) !== Continuous
        if relax
            setcurkind!(form, var, Continuous)
        end
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
            for (_, spform) in get_dw_pricing_sps(form.parent_formulation)
                for (col_id, col_coeff) in @view get_primal_sol_pool(spform)[:,varid]
                    coef_matrix[constrid, col_id] += col_coeff * var_coeff
                end
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
        if constrid.custom_family_id != -1
            coeff = computecoeff(var, var.custom_data, constr, constr.custom_data)
            if coeff != 0
                coef_matrix[constrid, getid(var)] = coeff
            end
        end
    end
    return
end

function _computenonrobustmembers(form::Formulation, constr::Constraint)
    coef_matrix = getcoefmatrix(form)
    for (varid, var) in getvars(form) # TODO : improve because we loop over all variables
        if varid.custom_family_id != -1
            coeff = computecoeff(var, var.custom_data, constr, constr.custom_data)
            if coeff != 0
                coef_matrix[getid(constr), varid] = coeff
            end
        end
    end
    return
end

function _setmembers!(form::Formulation, varconstr, members)
    _setrobustmembers!(form, varconstr, members)
    if getid(varconstr).custom_family_id != -1
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
    form.buffer.changed_obj_sense = true
    return
end

# TODO : remove (unefficient & specific to Benders)
function computereducedrhs(form::Formulation{BendersSp}, constrid::ConstrId, primalsol::PrimalSolution)
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
    for (varid, coeff) in @view getcoefmatrix(getmodel(primalsol))[constrid, :]
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

############################################################################################
# Methods to show a formulation
############################################################################################

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


"""
    PreprocessingStorage

    Storage for preprocessing. Contains global data: slacks of constraints,
    subproblem bounds, new constraints the local partial solution to preprocess.
    Contains also local data : stack of constraints to preprecess, as well as the
    vectors of preprocessed constraints and variables.  
"""

mutable struct PreprocessingStorage <: AbstractStorage
    # global data 
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    cur_sp_bounds::Dict{FormId,Tuple{Int,Int}}
    new_constrs::Vector{Tuple{ConstrId,Formulation}}
    local_partial_sol::Dict{VarId, Float64}

    # local data 
    stack::DS.Stack{Tuple{ConstId,Formulation}}
    constr_in_stack::Set{ConstrId}
    preprocessed_constrs::Vector{Constraint}
    preprocessed_vars::Vector{Variable}
end

function add_to_localpartialsol!(storage::PreprocessingStorage, varid::VarId, value::Float64)
    cur_value = get(storage.localpartialsol, varid, 0.0)
    storage.localpartialsol[varid] = cur_value + value
    return
end

# empty_local_solution!(storage::PreprocessingStorage) =
#     empty!(storage.localpartialsol)

# function get_local_primal_solution(storage::PreprocessingStorage, form::Formulation)
#     varids = collect(keys(storage.localpartialsol))
#     vals = collect(values(storage.localpartialsol))
#     solcost = 0.0
#     for (varid, value) in storage.localpartialsol
#         solcost += getcurcost(form, varid) * value
#     end
#     return PrimalSolution(form, varids, vals, solcost, UNKNOWN_FEASIBILITY)
# end    

function PreprocessingStorage(reform::Reformulation) 
    constraints = Tuple{ConstrId,Formulation}[]

    # Master constraints
    master = getmaster(reform)
    for (constrid, constr) in getconstrs(master)
        iscuractive(master, constrid) || continue
        isexplicit(master, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        push!(constraints, (constrid, master))   
    end
    
    # Subproblem constraints
    for (spuid, spform) in get_dw_pricing_sps(reformulation)
        for (constrid, constr) in getconstrs(spform)
            iscuractive(spform, constrid) || continue
            isexplicit(spform, constrid) || continue
            push!(constraints, (constrid, spform))   
        end
    end

    cur_sp_bounds = Dict{FormId,Tuple{Int,Int}}()
    for (spuid, spform) in get_dw_pricing_sps(reform)
        cur_sp_bounds[spuid] = (
            getcurrhs(master, get_dw_pricing_sp_lb_constrid(reform, spuid)), 
            getcurrhs(master, get_dw_pricing_sp_ub_constrid(reform, spuid))
        )
    end

    return PreprocessingStorage(
        Dict{ConstrId,Float64}(), Dict{ConstrId,Float64}(), 
        Dict{ConstrId,Int}(), Dict{ConstrId,Int}(), cur_sp_bounds,
        constraints, Dict{VarId, Float64}(), 
        DS.Stack{Tuple{Constraint,Formulation}}(), Set{ConstrId}(),
        Constraint[], Variable[])
end

mutable struct PreprocessingStorageState <: AbstractStorageState
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    cur_sp_bounds::Dict{FormId,Tuple{Int,Int}}
    new_constrs::Vector{Tuple{ConstrId,Formulation}}
    local_partial_sol::Dict{VarId, Float64}
end

function PreprocessingStorageState(reform::Reformulation, storage::PreprocessingStorage)
    return PreprocessingStorageState(
        copy(storage.cur_min_slack), copy(storage.cur_max_slack), 
        copy(storage.nb_inf_sources_for_min_slack),
        copy(storage.nb_inf_sources_for_max_slack),
        copy(storage.cur_sp_bounds), copy(storage.new_constrs), copy(storage.local_partial_sol))
end

function restorefromstate!(
    form::Reformulation, storage::PreprocessingStorage, state::PreprocessingStorageState
)
    storage.cur_min_slack = copy(state.cur_min_slack)
    storage.cur_max_slack = copy(state.cur_max_slack)
    storage.nb_inf_sources_for_min_slack = copy(state.nb_inf_sources_for_min_slack)
    storage.nb_inf_sources_for_max_slack = copy(state.nb_inf_sources_for_max_slack)
    storage.cur_sp_bounds = copy(state.cur_sp_bounds)
    storage.new_constrs = copy(state.new_constrs)
    storage.local_partial_sol = copy(state.local_partial_sol)
end

const PreprocessingStoragePair = (PreprocessingStorage => PreprocessingStorageState)


"""
    PreprocessingOutput

"""

struct PreprocessingOutput <: AbstractOutput
    infeasible::Bool
end

isinfeasible(output::PreprocessingOutput) = output.infeasible

"""
    PreprocessingAlgorithm

"""

@with_kw struct PreprocessAlgorithm <: AbstractAlgorithm 
    preprocess_subproblems::Bool = true # TO DO : this paramter is not yet implemented
    printing::Bool = false
end

# PreprocessAlgorithm does not have child algorithms, therefore get_child_algorithms() is not defined

function get_storages_usage(algo::PreprocessAlgorithm, form::Formulation) 
    return [(form, StaticVarConstrStoragePair, READ_AND_WRITE), 
            (form, PreprocessingStoragePair, READ_AND_WRITE)]
end

function get_storages_usage(algo::PreprocessAlgorithm, reform::Reformulation) 
    storages_usage = Tuple{AbstractModel, StorageTypePair, StorageAccessMode}[]     
    push!(storages_usage, (reform, PreprocessingStoragePair, READ_AND_WRITE))

    master = getmaster(reform)
    push!(storages_usage, (master, StaticVarConstrStoragePair, READ_AND_WRITE))
    push!(storages_usage, (master, MasterBranchConstrsStoragePair, READ_AND_WRITE))
    push!(storages_usage, (master, MasterCutsStoragePair, READ_AND_WRITE))

    if algo.preprocess_subproblems
        push!(storages_usage, (master, MasterColumnsStoragePair, READ_AND_WRITE))
        for (id, spform) in get_dw_pricing_sps(reform)
            push!(storages_usage, (spform, StaticVarConstrStoragePair, READ_AND_WRITE))
        end
    end
    return storages_usage
end

function run!(algo::PreprocessAlgorithm, rfdata::ReformData, input::EmptyInput)::PreprocessingOutput
    @logmsg LogLevel(-1) "Run preprocessing"

    storage = getstorage(rfdata, PreprocessingStoragePair)
    
    init_new_constraints!(algo, storage) && return OptimizationOutput(true)
    
    #stopped here
    
    local_primal_sol = get_local_primal_solution(storage, master)
    empty_local_solution!(storage)

    alg_data = PreprocessData(rfdata, local_primal_sol)
    master = getmaster(alg_data.reformulation)

    if initconstraints!(algo, alg_data, storage.newconstrs)
        return PreprocessingOutput(true)
    end

    fix_local_partial_solution!(algo, alg_data)


    # Now we try to update local bounds of sp vars
    for var in vars_with_modified_bounds
        update_lower_bound!(algo, alg_data, var, master, getcurlb(master, var), false)
        update_upper_bound!(algo, alg_data, var, master, getcurub(master, var), false)
    end

    infeasible = propagation!(algo, alg_data) 

    if !infeasible && algo.preprocess_subproblems
        forbid_infeasible_columns!(alg_data)
    end
    @logmsg LogLevel(0) "Preprocessing done."
    return PreprocessingOutput(infeasible)
end

function change_sp_bounds!(algo::PreprocessAlgorithm, alg_data::PreprocessData)
    reformulation = alg_data.reformulation
    master = getmaster(reformulation)
    sps_with_modified_bounds = []

    # @show getuid(master)
    # for (col_id, col_val) in alg_data.local_partial_sol
    #     println(getname(master, col_id), " origin id is ", col_id.origin_form_uid)
    # end

    for (col_id, col_val) in alg_data.local_partial_sol
        sp_form_uid = getoriginformuid(col_id)
        spform = get_dw_pricing_sps(reformulation)[sp_form_uid]
        lb_constr_id = reformulation.dw_pricing_sp_lb[sp_form_uid]
        ub_constr_id = reformulation.dw_pricing_sp_ub[sp_form_uid]
        if alg_data.cur_sp_bounds[sp_form_uid][1] > 0
            alg_data.cur_sp_bounds[sp_form_uid] = (
                max(alg_data.cur_sp_bounds[sp_form_uid][1] - col_val, 0),
                alg_data.cur_sp_bounds[sp_form_uid][2]
            )
            algo.printing && println(
                "Rhs of constr ", getname(master, lb_constr_id),
                " is changed from ", getcurrhs(master, lb_constr_id), 
                " to ", alg.cur_sp_bounds[sp_form_uid][1] 
            )
            setcurrhs!(master, lb_constr_id, Float64(alg.cur_sp_bounds[sp_form_uid][1]))
        end
        alg_data.cur_sp_bounds[sp_form_uid] = (
            alg_data.cur_sp_bounds[sp_form_uid][1],
            alg_data.cur_sp_bounds[sp_form_uid][2] - col_val
        )
        algo.printing && println(
            "Rhs of constr ", getname(master, ub_constr_id),
            " is changed from ", getcurrhs(master, ub_constr_id), 
            " to ", alg_data.cur_sp_bounds[sp_form_uid][2] 
        )
        setcurrhs!(master, ub_constr_id, Float64(alg_data.cur_sp_bounds[sp_form_uid][2]))
        @assert alg_data.cur_sp_bounds[sp_form_uid][2] >= 0
        if !(spform in sps_with_modified_bounds)
            push!(sps_with_modified_bounds, spform)
        end
    end
    return sps_with_modified_bounds
end

function project_local_partial_solution(alg_data::PreprocessData)
    sp_vars_vals = Dict{VarId,Float64}()
    primal_sp_sols = getprimalsolmatrix(getmaster(alg_data.reformulation))
    for (col, col_val) in alg_data.local_partial_sol
        for (sp_var_id, sp_var_val) in primal_sp_sols[:,getid(col)]
            if !haskey(sp_vars_vals, sp_var_id)
                sp_vars_vals[sp_var_id] = col_val * sp_var_val
            else
                sp_vars_vals[sp_var_id] += col_val * sp_var_val
            end
        end
    end
    return sp_vars_vals
end

function fix_local_partial_solution!(algo::PreprocessAlgorithm, alg_data::PreprocessData)
    isempty(alg_data.local_partial_sol) && return (Variable[], Constraint[])

    master = getmaster(alg_data.reformulation)
    master_coef_matrix = getcoefmatrix(master)
    constrs_with_modified_rhs = Constraint[]

    original_solution = proj_cols_on_rep(alg_data.local_partial_sol, master)
    algo.printing && print("Local partial solution in preprocessing is ", original_solution)

    # Updating rhs of master constraints
    for (varid, val) in original_solution
        for (constrid, coef) in master_coef_matrix[:,varid]
            iscuractive(master, constrid) || continue
            isexplicit(master, constrid) || continue
            getduty(constrid) != MasterConvexityConstr || continue
            algo.printing && println(
                "Rhs of constr ", getname(master, constrid), " is changed from ",
                getcurrhs(master, constrid), " to ", 
                getcurrhs(master, constrid) - val * coef
            )
            setcurrhs!(master, constrid, getcurrhs(master, constrid) - val * coef)
            push!(constrs_with_modified_rhs, getconstr(master, constrid))
        end
    end

    sps_with_modified_bounds = change_sp_bounds!(algo, alg_data)

    # for (varid, val) in original_solution
    #     @show getvar(master, varid)
    # end

    if !algo.preprocess_subproblems 
        return (Variable[], constrs_with_modified_rhs)
    end

    
    # Changing global bounds of subprob variables
    vars_with_modified_bounds = Variable[]
    for spform in sps_with_modified_bounds
        (cur_sp_lb, cur_sp_ub) = alg_data.cur_sp_bounds[getuid(spform)]

        for (varid, var) in getvars(spform)
            iscuractive(spform, varid) || continue
            getduty(varid) <=  AbstractDwSpVar || continue
            # var_val_in_local_sol = (
            #     haskey(sp_vars_vals, varid) ? sp_vars_vals[varid] : 0.0
            # )
            var_val_in_local_sol = original_solution[varid]
            # if !iszero(var_val_in_local_sol)
            #     println(getname(spform, varid), " has value ", var_val_in_local_sol, " in the local fixed solution")
            # end
            bounds_changed = false

            clone_in_master = getvar(master, varid)
            new_global_lb = max(
                getcurlb(master, clone_in_master) - var_val_in_local_sol,
                getcurlb(spform, var) * cur_sp_lb
            )
            if new_global_lb != getcurlb(master, clone_in_master)
                algo.printing && println(
                    "Global lower bound of var ", getname(master, clone_in_master), " is changed from ",
                    getcurlb(master, clone_in_master), " to ", new_global_lb
                )
                setlb!(master, clone_in_master) = new_global_lb
                bounds_changed = true
            end

            new_global_ub = min(
                getcurub(master, clone_in_master) - var_val_in_local_sol,
                getcurub(spform, var) * cur_sp_ub
            )
            if new_global_ub != getcurub(master, clone_in_master)
                algo.printing && println(
                    "Global upper bound of var ", getname(master, clone_in_master), " is changed from ",
                    getcurub(master, clone_in_master), " to ", new_global_ub
                )
                setub!(master, clone_in_master) = new_global_ub
                bounds_changed = true
            end

            if bounds_changed
                push!(vars_with_modified_bounds, clone_in_master)
            end
        end
    end
    return (vars_with_modified_bounds, constrs_with_modified_rhs)
end

function init_new_constraints!(algo::PreprocessAlgorithm, storage::PreprocessingStorage)

    for (constrid, form) in storage.newconstrs
        iscuractive(master, constrid) || continue
        isexplicit(master, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        algo.preprocess_subproblems || getduty(form) == DwMaster || continue

        storage.nb_inf_sources_for_min_slack[constrid] = 0
        storage.nb_inf_sources_for_max_slack[constrid] = 0
        compute_min_slack!(algo, storage, constrid, form) && return true
        compute_max_slack!(algo, storage, constrid, form) && return true
    
        push!(storage.constr_in_stack, constrid)
        push!(storage.stack, constrid)
    end
    empty!(storage.new_constrs)

    return false
end

function compute_min_slack!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, constrid::ConstrId, form::Formulation
    )
    slack = getcurrhs(form, constrid)
    if getduty(constrid) <= AbstractMasterConstr
        var_filter = (varid -> isanOriginalRepresentatives(varid))
    else
        var_filter = (varid -> (getduty(varid) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (varid, coef) in coef_matrix[constrid,:]
        var_filter(varid) || continue
        if coef > 0
            cur_ub = getcurub(form, varid)
            if cur_ub == Inf
                storage.nb_inf_sources_for_min_slack[constrid] += 1
            else
                slack -= coef * cur_ub
            end
        else
            cur_lb = getcurlb(form, varid)
            if cur_lb == -Inf
                storage.nb_inf_sources_for_min_slack[constrid] += 1
            else
                slack -= coef * cur_lb
            end
        end
    end
    algo.printing && println(
        "Min slack for constr ", getname(form, constrid), " is initialized to ", slack
    )
    storage.cur_min_slack[constrid] = slack
    return getcursense(form, constrid) != Less && slack > 0.0001
end

function compute_max_slack!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, constrid::ConstrId, form::Formulation
    )
    slack = getcurrhs(form, constrid)
    if getduty(constrid) <= AbstractMasterConstr
        var_filter = (varid -> isanOriginalRepresentatives(varid))
    else
        var_filter = (varid -> (getduty(varid) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (varid, coef) in coef_matrix[constrid,:]
        !var_filter(varid) || continue
        if coef > 0
            cur_lb = getcurlb(form, varid)
            if cur_lb == -Inf
                alg_data.nb_inf_sources_for_max_slack[constrid] += 1
            else
                slack -= coef * cur_lb
            end
        else
            cur_ub = getcurub(form, varid)
            if cur_ub == Inf
                alg_data.nb_inf_sources_for_max_slack[constrid] += 1
            else
                slack -= coef * cur_ub
            end
        end
    end
    algo.printing && println(
        "Max slack for constr ", getname(form, constrid), " is initialized to ", slack
    )
    storage.cur_max_slack[constrid] = slack
    return getcursense(form, constrid) != Greater && slack < -0.0001
end

function update_max_slack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation,
        var_was_inf_source::Bool, delta::Float64
    )
    alg_data.cur_max_slack[getid(constr)] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_max_slack[getid(constr)] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_max_slack[getid(constr)]
    sense = getcursense(form, constr)
    if nb_inf_sources == 0
        if (sense != Greater) && alg_data.cur_max_slack[getid(constr)] < -0.0001
            return true
        elseif (sense == Greater) && alg_data.cur_max_slack[getid(constr)] <= -0.0001
            # add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if sense != Greater
            add_to_stack!(alg_data, constr, form)
        end
    end
    return false
end

function update_min_slack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation,
        var_was_inf_source::Bool, delta::Float64
    )
    alg_data.cur_min_slack[getid(constr)] += delta
    if var_was_inf_source
        alg_data.nb_inf_sources_for_min_slack[getid(constr)] -= 1
    end

    nb_inf_sources = alg_data.nb_inf_sources_for_min_slack[getid(constr)]
    sense = getcursense(form, constr)
    if nb_inf_sources == 0
        if (sense != Less) && alg_data.cur_min_slack[getid(constr)] > 0.0001
            return true
        elseif (sense == Less) && alg_data.cur_min_slack[getid(constr)] >= 0.0001
            #add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1
        if sense != Less
            add_to_stack!(alg_data, constr, form)
        end
    end
    return false
end

function add_to_preprocessing_list!(alg_data::PreprocessData, var::Variable)
    if !(var in alg_data.preprocessed_vars)
        push!(alg_data.preprocessed_vars, var)
    end
    return
end

function add_to_preprocessing_list!(
       alg_data::PreprocessData, constr::Constraint
    )
    if !(constr in alg_data.preprocessed_constrs)
        push!(alg_data.preprocessed_constrs, constr)
    end
    return
end

function add_to_stack!(
        alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    if !alg_data.constr_in_stack[getid(constr)]
        push!(alg_data.stack, (constr, form))
        alg_data.constr_in_stack[getid(constr)] = true
    end
    return
end

function update_lower_bound!(
        algo::PreprocessAlgorithm, alg_data::PreprocessData, var::Variable, 
        form::Formulation, new_lb::Float64, check_monotonicity::Bool = true
    )
    varid = getid(var)
    if getduty(varid) == DwSpPricingVar && !algo.preprocess_subproblems
        return false
    end
    cur_lb = getcurlb(form, var)
    cur_ub = getcurub(form, var)
    if new_lb > cur_lb || !check_monotonicity
        if new_lb > cur_ub
            return true
        end

        diff = cur_lb == -Inf ? -new_lb : cur_lb - new_lb
        coef_matrix = getcoefmatrix(form)
        for (constrid, coef) in coef_matrix[:, varid]
            iscuractive(form, constrid) || continue
            isexplicit(form, constrid) || continue
            getduty(constrid) != MasterConvexityConstr || continue
            status = false
            if coef < 0 
                status = update_min_slack!(
                    alg_data, getconstr(form, constrid),
                    form, cur_lb == -Inf , diff * coef
                )
            else
                status = update_max_slack!(
                    alg_data, getconstr(form, constrid),
                    form, cur_lb == -Inf , diff * coef
                )
            end
            if status 
                return true
            end
        end
        algo.printing && new_lb > cur_lb && println(
            "updating lb of var ", getname(form, var), " from ", cur_lb, " to ",
            new_lb, " duty ", getduty(varid)
        )
        setcurlb!(form, var, new_lb)
        add_to_preprocessing_list!(alg_data, var)

        # Now we update bounds of clones
        if getduty(varid) == MasterRepPricingVar 
            subprob = find_owner_formulation(form.parent_formulation, var)
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(subprob)]
            clone_in_sp = getvar(subprob, varid)
            if update_lower_bound!(
                    algo, alg_data, clone_in_sp, subprob,
                    getcurlb(form, var) - (max(sp_ub, 1) - 1) * getcurub(subprob, clone_in_sp)
                )
                return true
            end
        elseif getduty(varid) == DwSpPricingVar
            master = form.parent_formulation
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(form)]
            clone_in_master = getvar(master, varid)
            if update_lower_bound!(
                    algo, alg_data, clone_in_master, master, getcurlb(form, varid) * sp_lb
                )
                return true
            end
            new_ub_in_sp = (
                getcurub(master, clone_in_master) - (max(sp_lb, 1) - 1) * getcurlb(form, varid)
            )
            if update_upper_bound!(algo, alg_data, var, form, new_ub_in_sp)
                return true
            end
        end
    end
    return false
end

function update_upper_bound!(
    algo::PreprocessAlgorithm, alg_data::PreprocessData, var::Variable, 
        form::Formulation, new_ub::Float64, check_monotonicity::Bool = true
    )
    varid = getid(var)
    if getduty(varid) == DwSpPricingVar && !algo.preprocess_subproblems
        return false
    end
    cur_lb = getcurlb(form, var)
    cur_ub = getcurub(form, var)
    if new_ub < cur_ub || !check_monotonicity
        if new_ub < cur_lb
            return true
        end
        
        diff = cur_ub == Inf ? -new_ub : cur_ub - new_ub
        coef_matrix = getcoefmatrix(form)
        for (constrid, coef) in coef_matrix[:, varid]
            iscuractive(form, constrid) || continue
            isexplicit(form, constrid) || continue
            getduty(constrid) != MasterConvexityConstr || continue
            status = false
            if coef > 0 
                status = update_min_slack!(
                    alg_data, getconstr(form, constrid),
                    form, cur_ub == Inf , diff * coef
                )
            else
                status = update_max_slack!(
                    alg_data, getconstr(form, constrid),
                    form, cur_ub == Inf , diff * coef
                )
            end
            if status
                return true
            end
        end
        if algo.printing && new_ub < cur_ub
            println(
            "updating ub of var ", getname(form, var), " from ", cur_ub,
            " to ", new_ub, " duty ", getduty(varid)
            )
        end
        setcurub!(form, varid, new_ub)
        add_to_preprocessing_list!(alg_data, var)
        
        # Now we update bounds of clones
        if getduty(varid) == MasterRepPricingVar 
            subprob = find_owner_formulation(form.parent_formulation, var)
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(subprob)]
            clone_in_sp = getvar(subprob, varid)
            if update_upper_bound!(
                algo, alg_data, clone_in_sp, subprob,
                getcurub(form, varid) - (max(sp_lb, 1) - 1) * getcurlb(subprob, clone_in_sp)
                )
                return true
            end
        elseif getduty(varid) == DwSpPricingVar
            master = form.parent_formulation
            (sp_lb, sp_ub) = alg_data.cur_sp_bounds[getuid(form)]
            clone_in_master = getvar(master, varid)
            if update_upper_bound!(
                algo, alg_data, clone_in_master, master, getcurub(form, varid) * sp_ub
                )
                return true
            end
            new_lb_in_sp = (
            getcurlb(master, clone_in_master) - (max(sp_ub, 1) - 1) * getcurub(form, varid)
            )
            if update_lower_bound!(algo, alg_data, var, form, new_lb_in_sp)
                return true
            end
        end
    end
    return false
end

function adjust_bound(form::Formulation, var::Variable, bound::Float64, is_upper::Bool)
    if getcurkind(form, var) != Continuous 
        bound = is_upper ? floor(bound) : ceil(bound)
    end
    return bound
end

function compute_new_bound(
    nb_inf_sources::Int, slack::Float64, var_contrib_to_slack::Float64,
    inf_bound::Float64, coef::Float64
    )
    if nb_inf_sources == 0
        bound = (slack - var_contrib_to_slack) / coef
    elseif nb_inf_sources == 1 && isinf(var_contrib_to_slack)
        bound = slack / coef 
    else
        bound = inf_bound
    end
    return bound
end

function compute_new_var_bound(
    alg_data::PreprocessData, var::Variable, form::Formulation, 
    cur_lb::Float64, cur_ub::Float64, coef::Float64, constr::Constraint
    )
    constrid = getid(constr)
    if coef > 0 && getcursense(form, constrid) == Less
        is_ub = true
        return (is_ub, compute_new_bound(
                alg_data.nb_inf_sources_for_max_slack[constrid],
                alg_data.cur_max_slack[constrid], -coef * cur_lb, Inf, coef
                ))
    elseif coef > 0 && getcursense(form, constrid) != Less
        is_ub = false
        return (is_ub, compute_new_bound(
                alg_data.nb_inf_sources_for_min_slack[constrid],
                alg_data.cur_min_slack[constrid], -coef * cur_ub, -Inf, coef
                ))
    elseif coef < 0 && getcursense(form, constrid) != Greater
        is_ub = false
        return (is_ub, compute_new_bound(
                alg_data.nb_inf_sources_for_max_slack[constrid],
                alg_data.cur_max_slack[constrid], -coef * cur_ub, -Inf, coef
                ))
    else
        is_ub = true
        return (is_ub, compute_new_bound(
                alg_data.nb_inf_sources_for_min_slack[constrid], 
                alg_data.cur_min_slack[constrid], -coef * cur_lb, Inf, coef
                ))
    end
end

function strengthen_var_bounds_in_constr!(
    algo::PreprocessAlgorithm, alg_data::PreprocessData, constr::Constraint, form::Formulation
    )
    constrid = getid(constr)
    if getduty(constrid) <= AbstractMasterConstr
        var_filter =  (var -> isanOriginalRepresentatives(getduty(getid(var))))
    else
        var_filter = (var -> (getduty(getid(var)) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (varid, coef) in coef_matrix[constrid,:]
        var = getvar(form, varid)
        if !var_filter(var) 
            continue
        end
        (is_ub, bound) = compute_new_var_bound(
            alg_data, var, form, getcurlb(form, varid), getcurub(form, varid), coef, constr
        )
        if !isinf(bound)
            bound = adjust_bound(form, var, bound, is_ub)
            status = false
            if is_ub
                status = update_upper_bound!(algo, alg_data, var, form, bound)
            else
                status = update_lower_bound!(algo, alg_data, var, form, bound)
            end
            if status
                return true
            end
        end
    end
    return false
end

function propagation!(algo::PreprocessAlgorithm, alg_data::PreprocessData)
    while !isempty(alg_data.stack)
        (constr, form) = pop!(alg_data.stack)
        alg_data.constr_in_stack[getid(constr)] = false
        
        # if algo.printing
        #     println("constr ", getname(form, constr), " ", typeof(constr), " popped")
        #     println(
        #         "rhs ", getcurrhs(form, constr), " max: ",
        #         alg_data.cur_max_slack[getid(constr)], " min: ",
        #         alg_data.cur_min_slack[getid(constr)]
        #     )
        # end
        if strengthen_var_bounds_in_constr!(algo, alg_data, constr, form)
            return true
        end
    end
    return false
end

function forbid_infeasible_columns!(alg_data::PreprocessData)
    master = getmaster(alg_data.reformulation)
    primal_sp_sols = getprimalsolmatrix(getmaster(alg_data.reformulation))
    for var in alg_data.preprocessed_vars
        varid = getid(var)
        if getduty(varid) == DwSpPricingVar
            for (col_id, coef) in primal_sp_sols[varid,:]
                if !(getcurlb(master, varid) <= coef <= getcurub(master, varid)) # TODO ; get the subproblem...
                    setcurub!(master, getvar(master, col_id), 0.0)
                end
            end
        end
    end
    return
end

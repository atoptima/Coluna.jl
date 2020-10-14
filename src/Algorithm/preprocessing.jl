
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
    stack::DS.Stack{Tuple{ConstrId,Formulation}}
    constrs_in_stack::Set{ConstrId}
    preprocessed_constrs::Set{ConstrId}
    preprocessed_vars::Set{VarId}
end

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
    for (spuid, spform) in get_dw_pricing_sps(reform)
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
        DS.Stack{Tuple{ConstrId,Formulation}}(), Set{ConstrId}(),
        Set{ConstrId}(), Set{VarId}())
end

function empty_local_data!(storage::PreprocessingStorage)
    empty!(stack)
    empty!(constrs_in_stack)
    empty!(preprocessed_constrs)
    empty!(preprocessed_vars)
end

function add_to_localpartialsol!(storage::PreprocessingStorage, varid::VarId, value::Float64)
    cur_value = get(storage.local_partial_sol, varid, 0.0)
    storage.local_partial_sol[varid] = cur_value + value
    return
end

function get_local_primal_solution(storage::PreprocessingStorage, form::Formulation)
    varids = collect(keys(storage.local_partial_sol))
    vals = collect(values(storage.local_partial_sol))
    solcost = 0.0
    for (varid, value) in storage.local_partial_sol
        solcost += getcurcost(form, varid) * value
    end
    return PrimalSolution(form, varids, vals, solcost, UNKNOWN_FEASIBILITY)
end    

function add_to_stack!(
    storage::PreprocessingStorage, constrid::ConstrId, form::Formulation
)
    if constrid ∉ storage.constrs_in_stack  
        push!(storage.constrs_in_stack, constrid)
        push!(storage.stack, (constrid, form))
    end
    return
end

function add_to_preprocessing_list!(storage::PreprocessingStorage, varid::VarId)
    if varid ∉ storage.preprocessed_vars
        push!(storage.preprocessed_vars, varid)
    end
    return
end

function add_to_preprocessing_list!(storage::PreprocessingStorage, constr::ConstrId)
    if constrid ∉ storage.preprocessed_constrs
        push!(storage.preprocessed_constrs, constr)
    end
    return
end

"""
    PreprocessingStorageState

    Stores the global part of preprocessing storage
"""

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

function run!(algo::PreprocessAlgorithm, data::ReformData, input::EmptyInput)::PreprocessingOutput
    @logmsg LogLevel(-1) "Run preprocessing"

    storage = getstorage(data, PreprocessingStoragePair)
    
    infeasible = init_new_constraints!(algo, storage) 

    !infeasible && 
        (infeasible = fix_local_partial_solution!(algo, storage, getmodel(getmasterdata(data))))

    # infeasible = propagation!(algo, alg_data) 

    # if !infeasible && algo.preprocess_subproblems
    #     forbid_infeasible_columns!(alg_data)
    # end
    @logmsg LogLevel(0) "Preprocessing done."

    empty_local_data!(storage)

    return PreprocessingOutput(infeasible)
end

function change_subprob_bounds!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, master::Formulation{DwMaster},
    original_solution::PrimalSolution
    )
    reformulation = master.parent_formulation

    sps_with_modified_bounds = []
    for (col_id, col_val) in storage.local_partial_sol
        getduty(col_id) <= MasterCol || continue
        sp_form_uid = getoriginformuid(col_id)
        spform = get_dw_pricing_sps(reformulation)[sp_form_uid]
        lb_constr_id = reformulation.dw_pricing_sp_lb[sp_form_uid]
        ub_constr_id = reformulation.dw_pricing_sp_ub[sp_form_uid]
        if storage.cur_sp_bounds[sp_form_uid][1] > 0
            storage.cur_sp_bounds[sp_form_uid] = (
                max(storage.cur_sp_bounds[sp_form_uid][1] - col_val, 0),
                storage.cur_sp_bounds[sp_form_uid][2]
            )
            algo.printing && println(
                "Rhs of constr ", getname(master, lb_constr_id),
                " is changed from ", getcurrhs(master, lb_constr_id), 
                " to ", storage.cur_sp_bounds[sp_form_uid][1] 
            )
            setcurrhs!(master, lb_constr_id, Float64(storage.cur_sp_bounds[sp_form_uid][1]))
        end
        storage.cur_sp_bounds[sp_form_uid] = (
            storage.cur_sp_bounds[sp_form_uid][1],
            storage.cur_sp_bounds[sp_form_uid][2] - col_val
        )
        algo.printing && println(
            "Rhs of constr ", getname(master, ub_constr_id),
            " is changed from ", getcurrhs(master, ub_constr_id), 
            " to ", storage.cur_sp_bounds[sp_form_uid][2] 
        )
        setcurrhs!(master, ub_constr_id, Float64(storage.cur_sp_bounds[sp_form_uid][2]))
        @assert storage.cur_sp_bounds[sp_form_uid][2] >= 0
        if spform ∉ sps_with_modified_bounds
            push!(sps_with_modified_bounds, spform)
        end
    end

    # Changing global bounds of subprob variables
    for spform in sps_with_modified_bounds
        (cur_sp_lb, cur_sp_ub) = storage.cur_sp_bounds[getuid(spform)]

        for (varid, var) in getvars(spform)
            iscuractive(spform, varid) || continue
            getduty(varid) <=  AbstractDwSpVar || continue
            var_val_in_local_sol = original_solution[varid]
            bounds_changed = false

            new_global_lb = max(
                getcurlb(master, varid) - var_val_in_local_sol,
                getcurlb(spform, varid) * cur_sp_lb
            )
            if update_lower_bound!(algo, storage, varid, master, new_global_lb) 
                return true
            end

            new_global_ub = min(
                getcurub(master, varid) - var_val_in_local_sol,
                getcurub(spform, varid) * cur_sp_ub
            )
            if update_upper_bound!(algo, storage, varid, master, new_global_ub)
                return true
            end 
        end
    end
        
end

function fix_local_partial_solution!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, form::Formulation
    )
    isempty(storage.local_partial_sol) && return false

    solution = get_local_primal_solution(storage, form)
    if isa(form, Formulation{DwMaster}) 
        solution = proj_cols_on_rep(solution, form)
    end
    algo.printing && print("Local partial solution in preprocessing is ", solution)

    coef_matrix = getcoefmatrix(form)
    # Updating rhs of master constraints
    for (varid, val) in solution
        for (constrid, coef) in coef_matrix[:,varid]
            iscuractive(form, constrid) || continue
            isexplicit(form, constrid) || continue
            getduty(constrid) != MasterConvexityConstr || continue
            algo.printing && println(
                "Rhs of constr ", getname(form, constrid), " is changed from ",
                getcurrhs(form, constrid), " to ", 
                getcurrhs(form, constrid) - val * coef
            )
            setcurrhs!(form, constrid, getcurrhs(form, constrid) - val * coef)
            add_to_stack!(storage, constrid, form)
        end
    end

    if isa(form, Formulation{DwMaster}) 
        infeasible = change_subprob_bounds!(algo, storage, form, solution)
    else    
        infeasible = false
    end

    empty!(storage.local_partial_sol)
    
    return infeasible 
end

function init_new_constraints!(algo::PreprocessAlgorithm, storage::PreprocessingStorage)

    for (constrid, form) in storage.new_constrs
        iscuractive(form, constrid) || continue
        isexplicit(form, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        algo.preprocess_subproblems || getduty(form) == DwMaster || continue

        storage.nb_inf_sources_for_min_slack[constrid] = 0
        storage.nb_inf_sources_for_max_slack[constrid] = 0
        compute_min_slack!(algo, storage, constrid, form) && return true
        compute_max_slack!(algo, storage, constrid, form) && return true
    
        push!(storage.constrs_in_stack, constrid)
        push!(storage.stack, (constrid, form))
    end
    empty!(storage.new_constrs)

    return false
end

function compute_min_slack!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, constrid::ConstrId, form::Formulation
    )
    slack = getcurrhs(form, constrid)
    if getduty(constrid) <= AbstractMasterConstr
        var_filter = (varid -> isanOriginalRepresentatives(getduty(varid)))
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
        var_filter = (varid -> isanOriginalRepresentatives(getduty(varid)))
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
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, constrid::ConstrId, 
    form::Formulation, var_was_inf_source::Bool, delta::Float64
    )

    algo.printing && println(
        "Max slack for constr ", getname(form, constrid), " is changed from ",
        storage.cur_max_slack[constrid], " to ", storage.cur_max_slack[constrid] + delta
    )
    storage.cur_max_slack[constrid] += delta
    if var_was_inf_source
        storage.nb_inf_sources_for_max_slack[constrid] -= 1
    end

    nb_inf_sources = storage.nb_inf_sources_for_max_slack[constrid]
    sense = getcursense(form, constrid)
    if nb_inf_sources == 0
        if (sense != Greater) && storage.cur_max_slack[constrid] < -0.0001
            return true
        elseif (sense == Greater) && storage.cur_max_slack[constrid] <= -0.0001
            # add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1 && sense != Greater
        add_to_stack!(storage, constrid, form)
    end
    return false
end

function update_min_slack!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, constrid::ConstrId, 
    form::Formulation, var_was_inf_source::Bool, delta::Float64
    )
    algo.printing && println(
        "Min slack for constr ", getname(form, constrid), " is changed from ",
        storage.cur_min_slack[constrid], " to ", storage.cur_min_slack[constrid] + delta
    )
    storage.cur_min_slack[constrid] += delta
    if var_was_inf_source
        storage.nb_inf_sources_for_min_slack[constrid] -= 1
    end

    nb_inf_sources = storage.nb_inf_sources_for_min_slack[constrid]
    sense = getcursense(form, constrid)
    if nb_inf_sources == 0
        if (sense != Less) && storage.cur_min_slack[constrid] > 0.0001
            return true
        elseif (sense == Less) && storage.cur_min_slack[constrid] >= 0.0001
            #add_to_preprocessing_list(alg, constr)
            return false
        end
    end
    if nb_inf_sources <= 1 && sense != Less
        add_to_stack!(storage, constrid, form)
    end
    return false
end

function update_lower_bound!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, varid::VarId, 
    form::Formulation, new_lb::Float64
    )
    if getduty(varid) == DwSpPricingVar && !algo.preprocess_subproblems
        return false
    end
    cur_lb = getcurlb(form, varid)
    cur_ub = getcurub(form, varid)

    new_lb <= cur_lb && return false

    algo.printing && println(IOContext(stdout, :compact => true),
        "Lower bound of var ", getname(form, varid), " of type ", getduty(varid), 
        " in ", form, " is changed from ", cur_lb, " to ", new_lb
    )

    new_lb > cur_ub && return true

    diff = cur_lb == -Inf ? -new_lb : cur_lb - new_lb
    coef_matrix = getcoefmatrix(form)
    for (constrid, coef) in coef_matrix[:, varid]
        iscuractive(form, constrid) || continue
        isexplicit(form, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        infeasible = false
        if coef < 0 
            infeasible = update_min_slack!(
                algo, storage, constrid, form, cur_lb == -Inf, diff * coef
            )
        else
            infeasible = update_max_slack!(
                algo, storage, constrid, form, cur_lb == -Inf , diff * coef
            )
        end
        infeasible && return true
    end
    setcurlb!(form, varid, new_lb)
    add_to_preprocessing_list!(storage, varid)

    # Now we update bounds of clones
    if getduty(varid) == MasterRepPricingVar 
        subprob = find_owner_formulation(form.parent_formulation, var)
        (sp_lb, sp_ub) = storage.cur_sp_bounds[getuid(subprob)]
        if update_lower_bound!(
                algo, storage, varid, subprob,
                getcurlb(form, varid) - (max(sp_ub, 1) - 1) * getcurub(subprob, varid)
            )
            return true
        end
    elseif getduty(varid) == DwSpPricingVar
        master = form.parent_formulation
        (sp_lb, sp_ub) = storage.cur_sp_bounds[getuid(form)]
        if update_lower_bound!(
                algo, storage, varid, master, getcurlb(form, varid) * sp_lb
            )
            return true
        end
        new_ub_in_sp = (
            getcurub(master, varid) - (max(sp_lb, 1) - 1) * getcurlb(form, varid)
        )
        if update_upper_bound!(algo, storage, varid, form, new_ub_in_sp)
            return true
        end
    end

    return false
end

function update_upper_bound!(
    algo::PreprocessAlgorithm, storage::PreprocessingStorage, varid::VarId, 
    form::Formulation, new_ub::Float64
    )
    if getduty(varid) == DwSpPricingVar && !algo.preprocess_subproblems
        return false
    end
    cur_lb = getcurlb(form, varid)
    cur_ub = getcurub(form, varid)
    new_ub >= cur_ub  && return false
    
    new_ub < cur_lb && return true
        
    algo.printing && println(IOContext(stdout, :compact => true),
        "Upper bound of var ", getname(form, varid), " of type ", getduty(varid), 
        " in ", form, " is changed from ", cur_ub, " to ", new_ub
    )

    diff = cur_ub == Inf ? -new_ub : cur_ub - new_ub
    coef_matrix = getcoefmatrix(form)
    for (constrid, coef) in coef_matrix[:, varid]
        iscuractive(form, constrid) || continue
        isexplicit(form, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        infeasible = false
        if coef > 0 
            infeasible = update_min_slack!(
                algo, storage, constrid, form, cur_ub == Inf , diff * coef
            )
        else
            infeasible = update_max_slack!(
                algo, storage, constrid, form, cur_ub == Inf , diff * coef
            )
        end
        infeasible && return true
    end

    setcurub!(form, varid, new_ub)
    add_to_preprocessing_list!(storage, varid)
    
    # Now we update bounds of clones
    if getduty(varid) == MasterRepPricingVar 
        subprob = find_owner_formulation(form.parent_formulation, varid)
        (sp_lb, sp_ub) = storage.cur_sp_bounds[getuid(subprob)]
        if update_upper_bound!(
            algo, storage, varid, subprob,
            getcurub(form, varid) - (max(sp_lb, 1) - 1) * getcurlb(subprob, varid)
            )
            return true
        end
    elseif getduty(varid) == DwSpPricingVar
        master = form.parent_formulation
        (sp_lb, sp_ub) = storage.cur_sp_bounds[getuid(form)]
        if update_upper_bound!(
            algo, storage, varid, master, getcurub(form, varid) * sp_ub
            )
            return true
        end
        new_lb_in_sp = (
            getcurlb(master, varid) - (max(sp_ub, 1) - 1) * getcurub(form, varid)
            )
        if update_lower_bound!(algo, storage, varid, form, new_lb_in_sp)
            return true
        end
    end

    return false
end

# function adjust_bound(form::Formulation, var::Variable, bound::Float64, is_upper::Bool)
#     if getcurkind(form, var) != Continuous 
#         bound = is_upper ? floor(bound) : ceil(bound)
#     end
#     return bound
# end

# function compute_new_bound(
#     nb_inf_sources::Int, slack::Float64, var_contrib_to_slack::Float64,
#     inf_bound::Float64, coef::Float64
#     )
#     if nb_inf_sources == 0
#         bound = (slack - var_contrib_to_slack) / coef
#     elseif nb_inf_sources == 1 && isinf(var_contrib_to_slack)
#         bound = slack / coef 
#     else
#         bound = inf_bound
#     end
#     return bound
# end

# function compute_new_var_bound(
#     alg_data::PreprocessData, var::Variable, form::Formulation, 
#     cur_lb::Float64, cur_ub::Float64, coef::Float64, constr::Constraint
#     )
#     constrid = getid(constr)
#     if coef > 0 && getcursense(form, constrid) == Less
#         is_ub = true
#         return (is_ub, compute_new_bound(
#                 alg_data.nb_inf_sources_for_max_slack[constrid],
#                 alg_data.cur_max_slack[constrid], -coef * cur_lb, Inf, coef
#                 ))
#     elseif coef > 0 && getcursense(form, constrid) != Less
#         is_ub = false
#         return (is_ub, compute_new_bound(
#                 alg_data.nb_inf_sources_for_min_slack[constrid],
#                 alg_data.cur_min_slack[constrid], -coef * cur_ub, -Inf, coef
#                 ))
#     elseif coef < 0 && getcursense(form, constrid) != Greater
#         is_ub = false
#         return (is_ub, compute_new_bound(
#                 alg_data.nb_inf_sources_for_max_slack[constrid],
#                 alg_data.cur_max_slack[constrid], -coef * cur_ub, -Inf, coef
#                 ))
#     else
#         is_ub = true
#         return (is_ub, compute_new_bound(
#                 alg_data.nb_inf_sources_for_min_slack[constrid], 
#                 alg_data.cur_min_slack[constrid], -coef * cur_lb, Inf, coef
#                 ))
#     end
# end

# function strengthen_var_bounds_in_constr!(
#     algo::PreprocessAlgorithm, alg_data::PreprocessData, constr::Constraint, form::Formulation
#     )
#     constrid = getid(constr)
#     if getduty(constrid) <= AbstractMasterConstr
#         var_filter =  (var -> isanOriginalRepresentatives(getduty(getid(var))))
#     else
#         var_filter = (var -> (getduty(getid(var)) == DwSpPricingVar))
#     end
#     coef_matrix = getcoefmatrix(form)
#     for (varid, coef) in coef_matrix[constrid,:]
#         var = getvar(form, varid)
#         if !var_filter(var) 
#             continue
#         end
#         (is_ub, bound) = compute_new_var_bound(
#             alg_data, var, form, getcurlb(form, varid), getcurub(form, varid), coef, constr
#         )
#         if !isinf(bound)
#             bound = adjust_bound(form, var, bound, is_ub)
#             status = false
#             if is_ub
#                 status = update_upper_bound!(algo, alg_data, var, form, bound)
#             else
#                 status = update_lower_bound!(algo, alg_data, var, form, bound)
#             end
#             if status
#                 return true
#             end
#         end
#     end
#     return false
# end

# function propagation!(algo::PreprocessAlgorithm, alg_data::PreprocessData)
#     while !isempty(alg_data.stack)
#         (constr, form) = pop!(alg_data.stack)
#         alg_data.constr_in_stack[getid(constr)] = false
        
#         # if algo.printing
#         #     println("constr ", getname(form, constr), " ", typeof(constr), " popped")
#         #     println(
#         #         "rhs ", getcurrhs(form, constr), " max: ",
#         #         alg_data.cur_max_slack[getid(constr)], " min: ",
#         #         alg_data.cur_min_slack[getid(constr)]
#         #     )
#         # end
#         if strengthen_var_bounds_in_constr!(algo, alg_data, constr, form)
#             return true
#         end
#     end
#     return false
# end

# function forbid_infeasible_columns!(alg_data::PreprocessData)
#     master = getmaster(alg_data.reformulation)
#     primal_sp_sols = getprimalsolmatrix(getmaster(alg_data.reformulation))
#     for var in alg_data.preprocessed_vars
#         varid = getid(var)
#         if getduty(varid) == DwSpPricingVar
#             for (col_id, coef) in primal_sp_sols[varid,:]
#                 if !(getcurlb(master, varid) <= coef <= getcurub(master, varid)) # TODO ; get the subproblem...
#                     setcurub!(master, getvar(master, col_id), 0.0)
#                 end
#             end
#         end
#     end
#     return
# end

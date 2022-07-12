
"""
    PreprocessingUnit

    Storage unit for preprocessing. Contains global data: slacks of constraints,
    subproblem bounds, new constraints the local partial solution to preprocess.
    Contains also local data : stack of constraints to preprecess, as well as the
    vectors of preprocessed constraints and variables.  
"""

mutable struct PreprocessingUnit <: AbstractStorageUnit
    # global data 
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    cur_sp_lower_bounds::Dict{FormId,Int}
    cur_sp_upper_bounds::Dict{FormId,Int}
    new_constrs::Vector{Tuple{ConstrId,Formulation}}
    local_partial_sol::Dict{VarId, Float64}

    # local data 
    stack::DS.Stack{Tuple{ConstrId,Formulation}}
    constrs_in_stack::Set{ConstrId}
    preprocessed_constrs::Set{Tuple{ConstrId,Formulation}}
    sp_vars_with_changed_bounds::Set{Tuple{VarId,Formulation}}
end

function PreprocessingUnit(reform::Reformulation) 
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

    cur_sp_lower_bounds = Dict{FormId,Int}()
    cur_sp_upper_bounds = Dict{FormId,Int}()
    for (spuid, spform) in get_dw_pricing_sps(reform)
        cur_sp_lower_bounds[spuid] = 
            getcurrhs(master, get_dw_pricing_sp_lb_constrid(reform, spuid))
        cur_sp_upper_bounds[spuid] = 
            getcurrhs(master, get_dw_pricing_sp_ub_constrid(reform, spuid))
    end

    return PreprocessingUnit(
        Dict{ConstrId,Float64}(), Dict{ConstrId,Float64}(), 
        Dict{ConstrId,Int}(), Dict{ConstrId,Int}(), cur_sp_lower_bounds,
        cur_sp_upper_bounds, constraints, Dict{VarId, Float64}(), 
        DS.Stack{Tuple{ConstrId,Formulation}}(), Set{ConstrId}(),
        Set{Tuple{ConstrId,Formulation}}(), Set{Tuple{VarId, Formulation}}())
end

function empty_local_data!(unit::PreprocessingUnit)
    empty!(unit.stack)
    empty!(unit.constrs_in_stack)
    empty!(unit.preprocessed_constrs)
    empty!(unit.sp_vars_with_changed_bounds)
end

function add_to_localpartialsol!(unit::PreprocessingUnit, varid::VarId, value::Float64)
    cur_value = get(unit.local_partial_sol, varid, 0.0)
    unit.local_partial_sol[varid] = cur_value + value
    return
end

function get_local_primal_solution(unit::PreprocessingUnit, form::Formulation)
    varids = collect(keys(unit.local_partial_sol))
    vals = collect(values(unit.local_partial_sol))
    solcost = 0.0
    for (varid, value) in unit.local_partial_sol
        solcost += getcurcost(form, varid) * value
    end
    return PrimalSolution(form, varids, vals, solcost, UNKNOWN_FEASIBILITY)
end    

function add_to_stack!(
    unit::PreprocessingUnit, constrid::ConstrId, form::Formulation
)
    if constrid ∉ unit.constrs_in_stack  
        push!(unit.constrs_in_stack, constrid)
        push!(unit.stack, (constrid, form))
    end
    return
end

"""
    PreprocessingRecord

    Stores the global part of preprocessing unit
"""

mutable struct PreprocessingRecord <: AbstractRecord
    cur_min_slack::Dict{ConstrId,Float64}
    cur_max_slack::Dict{ConstrId,Float64}
    nb_inf_sources_for_min_slack::Dict{ConstrId,Int}
    nb_inf_sources_for_max_slack::Dict{ConstrId,Int}
    cur_sp_lower_bounds::Dict{FormId,Int}
    cur_sp_upper_bounds::Dict{FormId,Int}
    new_constrs::Vector{Tuple{ConstrId,Formulation}}
    local_partial_sol::Dict{VarId, Float64}
end

function PreprocessingRecord(reform::Reformulation, unit::PreprocessingUnit)
    return PreprocessingRecord(
        copy(unit.cur_min_slack), copy(unit.cur_max_slack), 
        copy(unit.nb_inf_sources_for_min_slack),
        copy(unit.nb_inf_sources_for_max_slack),
        copy(unit.cur_sp_lower_bounds), copy(unit.cur_sp_upper_bounds), 
        copy(unit.new_constrs), copy(unit.local_partial_sol))
end

function ColunaBase.restore_from_record!(
    form::Reformulation, unit::PreprocessingUnit, state::PreprocessingRecord
)
    unit.cur_min_slack = copy(state.cur_min_slack)
    unit.cur_max_slack = copy(state.cur_max_slack)
    unit.nb_inf_sources_for_min_slack = copy(state.nb_inf_sources_for_min_slack)
    unit.nb_inf_sources_for_max_slack = copy(state.nb_inf_sources_for_max_slack)
    unit.cur_sp_lower_bounds = copy(state.cur_sp_lower_bounds)
    unit.cur_sp_upper_bounds = copy(state.cur_sp_upper_bounds)
    unit.new_constrs = copy(state.new_constrs)
    unit.local_partial_sol = copy(state.local_partial_sol)
end

ColunaBase.record_type(::Type{PreprocessingUnit}) = PreprocessingRecord


"""
    PreprocessingOutput

"""

struct PreprocessingOutput <: AbstractOutput
    infeasible::Bool
end

#isinfeasible(output::PreprocessingOutput) = output.infeasible

"""
    PreprocessingAlgorithm

"""

@with_kw struct PreprocessAlgorithm <: AbstractAlgorithm 
    preprocess_subproblems::Bool = true # TO DO : this paramter is not yet implemented
    printing::Bool = false
end

function get_units_usage(algo::PreprocessAlgorithm, form::Formulation) 
    return [(form, StaticVarConstrUnit, READ_AND_WRITE), 
            (form, PreprocessingUnit, READ_AND_WRITE)]
end

function get_units_usage(algo::PreprocessAlgorithm, reform::Reformulation) 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[]     
    push!(units_usage, (reform, PreprocessingUnit, READ_AND_WRITE))

    master = getmaster(reform)
    push!(units_usage, (master, StaticVarConstrUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterBranchConstrsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterCutsUnit, READ_AND_WRITE))

    if algo.preprocess_subproblems
        push!(units_usage, (master, MasterColumnsUnit, READ_AND_WRITE))
        for (id, spform) in get_dw_pricing_sps(reform)
            push!(units_usage, (spform, StaticVarConstrUnit, READ_AND_WRITE))
        end
    end
    return units_usage
end

function run!(algo::PreprocessAlgorithm, env::Env, reform::Reformulation, input::EmptyInput)::PreprocessingOutput
    @logmsg LogLevel(-1) "Run preprocessing"

    unit = getstorageunit(reform, PreprocessingUnit)
    
    infeasible = init_new_constraints!(algo, unit)

    master = getmaster(reform)
    !infeasible && (infeasible = fix_local_partial_solution!(algo, unit, master))

    !infeasible && (infeasible = propagation!(algo, unit))

    !infeasible && algo.preprocess_subproblems && forbid_infeasible_columns!(algo, unit, master)

    !infeasible && remove_preprocessed_constraints(algo, unit)

    @logmsg LogLevel(0) (infeasible ? "Preprocessing determined infeasibility" 
                                    : "Preprocessing done.")
    empty_local_data!(unit)

    return PreprocessingOutput(infeasible)
end

function change_sp_lower_bound!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, spform::Formulation{DwSp}, newbound::Int
    )
    spuid = getuid(spform)
    curbound = unit.cur_sp_lower_bounds[spuid]
    newbound = max(newbound, 0)
    if curbound > newbound
        master = spform.parent_formulation
        reformulation = master.parent_formulation
        lb_constr_id = reformulation.dw_pricing_sp_lb[spuid]
        algo.printing && println(
            "Rhs of constr ", getname(master, lb_constr_id),
            " is changed from ", Float64(curbound), " to ", Float64(newbound)
        )
        setcurrhs!(master, lb_constr_id, Float64(newbound))
        unit.cur_sp_lower_bounds[spuid] = newbound
    end 
end

function change_sp_upper_bound!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, spform::Formulation{DwSp}, newbound::Int;
    update_global_var_bounds::Bool = false
    )
    @assert newbound >= 0
    spuid = getuid(spform)
    curbound = unit.cur_sp_upper_bounds[spuid]
    if curbound > newbound
        master = spform.parent_formulation
        reformulation = master.parent_formulation
        ub_constr_id = reformulation.dw_pricing_sp_ub[spuid]
        algo.printing && println(
            "Rhs of constr ", getname(master, ub_constr_id),
            " is changed from ", Float64(curbound), " to ", Float64(newbound)
        )
        setcurrhs!(master, ub_constr_id, Float64(newbound))
        unit.cur_sp_upper_bounds[spuid] = newbound

        if update_global_var_bounds
            for (varid, var) in getvars(spform)
                update_bounds_of_master_representative!(algo, unit, varid, spform)

            end
        end
    end 
end

function update_bounds_of_master_representative!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, varid::VarId, spform::Formulation{DwSp};
    value_to_substract::Float64 = 0.0
    )
    iscuractive(spform, varid) || return false
    getduty(varid) <= DwSpPricingVar || return false
    master = spform.parent_formulation
    spuid = getuid(spform)

    # it is important to update first the lower bound and then the upper bound, 
    # as the changes are imposed here and not verified for monotonicity

    new_global_lb = max(
        getcurlb(master, varid) - value_to_substract, 
        getcurlb(spform, varid) * unit.cur_sp_lower_bounds[spuid]
    )
    if update_lower_bound!(
        algo, unit, getvar(master, varid), master, new_global_lb, 
        check_monotonicity = false) # this is to impose the bound change 
        return true
    end

    new_global_ub = min(
        getcurub(master, varid) - value_to_substract,
        getcurub(spform, varid) * unit.cur_sp_upper_bounds[spuid]
    )
    if update_upper_bound!(algo, unit, getvar(master, varid), master, new_global_ub)
        return true
    end 
    return false
end

function change_subprob_bounds!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, master::Formulation{DwMaster},
    original_solution::PrimalSolution
    )

    sps_with_modified_bounds = Set{Formulation}()
    reformulation = master.parent_formulation
    for (col_id, col_val) in unit.local_partial_sol
        getduty(col_id) <= MasterCol || continue
        spuid = getoriginformuid(col_id)
        spform = get_dw_pricing_sps(reformulation)[spuid]

        new_lower_bound = max(unit.cur_sp_lower_bounds[spuid] - Int64(col_val), 0)
        change_sp_lower_bound!(algo, unit, spform, new_lower_bound)

        new_upper_bound = unit.cur_sp_upper_bounds[spuid] - Int64(col_val)
        change_sp_upper_bound!(algo, unit, spform, new_upper_bound)

        push!(sps_with_modified_bounds, spform)
    end

    # Changing global bounds of subprob variables
    for spform in sps_with_modified_bounds
        for (varid, var) in getvars(spform)
            if update_bounds_of_master_representative!(
                algo, unit, varid, spform, value_to_substract = original_solution[varid]
                )
                return true
            end
        end
    end
    return false    
end

function fix_local_partial_solution!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, form::Formulation
    )
    isempty(unit.local_partial_sol) && return false

    solution = get_local_primal_solution(unit, form)
    if isa(form, Formulation{DwMaster}) 
        solution = proj_cols_on_rep(solution, form)
    end
    algo.printing && print("Local partial solution in preprocessing is ", solution)

    coef_matrix = getcoefmatrix(form)
    # Updating rhs of master constraints
    for (varid, val) in solution
        for (constrid, coef) in @view coef_matrix[:,varid]
            iscuractive(form, constrid) || continue
            isexplicit(form, constrid) || continue
            getduty(constrid) != MasterConvexityConstr || continue
            algo.printing && println(
                "Rhs of constr ", getname(form, constrid), " is changed from ",
                getcurrhs(form, constrid), " to ", 
                getcurrhs(form, constrid) - val * coef
            )
            setcurrhs!(form, constrid, getcurrhs(form, constrid) - val * coef)
            update_min_slack!(algo, unit, constrid, form, false, - val * coef)
            update_max_slack!(algo, unit, constrid, form, false, - val * coef)

        end
    end

    if isa(form, Formulation{DwMaster}) 
        infeasible = change_subprob_bounds!(algo, unit, form, solution)
    else    
        infeasible = false
    end

    empty!(unit.local_partial_sol)
    
    return infeasible 
end

function init_new_constraints!(algo::PreprocessAlgorithm, unit::PreprocessingUnit)

    for (constrid, form) in unit.new_constrs
        iscuractive(form, constrid) || continue
        isexplicit(form, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        algo.preprocess_subproblems || isa(form, Formulation{DwMaster}) || continue

        unit.nb_inf_sources_for_min_slack[constrid] = 0
        unit.nb_inf_sources_for_max_slack[constrid] = 0
        compute_min_slack!(algo, unit, constrid, form) && return true
        compute_max_slack!(algo, unit, constrid, form) && return true
    
        push!(unit.constrs_in_stack, constrid)
        push!(unit.stack, (constrid, form))
    end
    empty!(unit.new_constrs)

    return false
end

function check_min_slack!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, form::Formulation{Duty}
    ) where {Duty}
    slack = unit.cur_min_slack[constrid]
    if getcursense(form, constrid) != Less && slack > 0.0001
        if Duty == DwSp && unit.cur_sp_lower_bounds[getuid(form)] == 0
            # the subproblem becomes infeasible, but, as its lower bound is zero
            # this does not result in infeasibility of the master
            change_sp_upper_bound!(algo, unit, form, 0, update_global_var_bounds = true)
            return false
        else
            return true
        end
    end
    return false
end

function check_max_slack!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, form::Formulation{Duty}
    ) where {Duty}
    slack = unit.cur_max_slack[constrid]
    if getcursense(form, constrid) != Greater && slack < -0.0001
        if Duty == DwSp && unit.cur_sp_lower_bounds[getuid(form)] == 0
            # the subproblem becomes infeasible, but, as its lower bound is zero
            # this does not result in infeasibility of the master
            change_sp_upper_bound!(algo, unit, form, 0, update_global_var_bounds = true)
            return false
        else
            return true
        end
    end
    return false
end

function compute_min_slack!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, form::Formulation
    )
    slack = getcurrhs(form, constrid)
    if getduty(constrid) <= AbstractMasterConstr
        var_filter = (varid -> isanOriginalRepresentatives(getduty(varid)))
    else
        var_filter = (varid -> (getduty(varid) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (varid, coef) in @view coef_matrix[constrid,:]
        var_filter(varid) || continue
        if coef > 0
            cur_ub = getcurub(form, varid)
            if cur_ub == Inf
                unit.nb_inf_sources_for_min_slack[constrid] += 1
            else
                slack -= coef * cur_ub
            end
        else
            cur_lb = getcurlb(form, varid)
            if cur_lb == -Inf
                unit.nb_inf_sources_for_min_slack[constrid] += 1
            else
                slack -= coef * cur_lb
            end
        end
    end
    algo.printing && println(
        "Min slack for constr ", getname(form, constrid), " is initialized to ", slack
    )
    unit.cur_min_slack[constrid] = slack
    return check_min_slack!(algo, unit, constrid, form)
end

function compute_max_slack!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, form::Formulation
    )
    slack = getcurrhs(form, constrid)
    if getduty(constrid) <= AbstractMasterConstr
        var_filter = (varid -> isanOriginalRepresentatives(getduty(varid)))
    else
        var_filter = (varid -> (getduty(varid) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (varid, coef) in @view coef_matrix[constrid,:]
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
    unit.cur_max_slack[constrid] = slack
    return check_max_slack!(algo, unit, constrid, form)
end

function update_max_slack!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, 
    form::Formulation, var_was_inf_source::Bool, delta::Float64
    )

    algo.printing && println(
        "Max slack for constr ", getname(form, constrid), " is changed from ",
        unit.cur_max_slack[constrid], " to ", unit.cur_max_slack[constrid] + delta
    )
    unit.cur_max_slack[constrid] += delta
    if var_was_inf_source
        unit.nb_inf_sources_for_max_slack[constrid] -= 1
    end

    nb_inf_sources = unit.nb_inf_sources_for_max_slack[constrid]
    sense = getcursense(form, constrid)
    if nb_inf_sources == 0
        if check_max_slack!(algo, unit, constrid, form)
            return true
        elseif (sense == Greater) && unit.cur_max_slack[constrid] <= -0.0001
            if (constrid,form) ∉ unit.preprocessed_constrs
                push!(unit.preprocessed_constrs, (constrid,form))
            end
            return false
        end
    end
    if nb_inf_sources <= 1 && sense != Greater
        add_to_stack!(unit, constrid, form)
    end
    return false
end

function update_min_slack!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, 
    form::Formulation, var_was_inf_source::Bool, delta::Float64
    )
    algo.printing && println(
        "Min slack for constr ", getname(form, constrid), " is changed from ",
        unit.cur_min_slack[constrid], " to ", unit.cur_min_slack[constrid] + delta
    )
    unit.cur_min_slack[constrid] += delta
    if var_was_inf_source
        unit.nb_inf_sources_for_min_slack[constrid] -= 1
    end

    nb_inf_sources = unit.nb_inf_sources_for_min_slack[constrid]
    sense = getcursense(form, constrid)
    if nb_inf_sources == 0
        if check_min_slack!(algo, unit, constrid, form)
            return true
        elseif (sense == Less) && unit.cur_min_slack[constrid] >= 0.0001
            if (constrid,form) ∉ unit.preprocessed_constrs
                push!(unit.preprocessed_constrs, (constrid,form))
            end
            return false
        end
    end
    if nb_inf_sources <= 1 && sense != Less
        add_to_stack!(unit, constrid, form)
    end
    return false
end

function update_lower_bound!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, var::Variable, 
    form::Formulation{Duty}, new_lb::Float64; check_monotonicity::Bool = true
    ) where {Duty}
    varid = getid(var)
    if Duty == DwSp
        if !algo.preprocess_subproblems || unit.cur_sp_upper_bounds[getuid(form)] == 0
            return false
        end
    end
    cur_lb = getcurlb(form, varid)
    cur_ub = getcurub(form, varid)

    check_monotonicity && new_lb <= cur_lb && return false

    algo.printing && println(IOContext(stdout, :compact => true),
        "Lower bound of var ", getname(form, varid), " of type ", getduty(varid), 
        " in ", form, " is changed from ", cur_lb, " to ", new_lb
    )

    if new_lb > cur_ub 
        if Duty == DwSp && unit.cur_sp_upper_bounds[getuid(form)] == 0
            change_sp_upper_bound!(algo, unit, form, 0, update_global_var_bounds = true)
            return false
        else    
            return true
        end
    end

    diff = cur_lb == -Inf ? -new_lb : cur_lb - new_lb
    coef_matrix = getcoefmatrix(form)
    for (constrid, coef) in @view coef_matrix[:, varid]
        iscuractive(form, constrid) || continue
        isexplicit(form, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        infeasible = false
        if coef < 0 
            infeasible = update_min_slack!(
                algo, unit, constrid, form, cur_lb == -Inf, diff * coef
            )
        else
            infeasible = update_max_slack!(
                algo, unit, constrid, form, cur_lb == -Inf , diff * coef
            )
        end
        infeasible && return true
    end
    
    setcurlb!(form, varid, new_lb)
    if Duty == DwSp && (varid,form) ∉ unit.sp_vars_with_changed_bounds
        push!(unit.sp_vars_with_changed_bounds, (varid,form))
    end

    # Now we update bounds of clones
    if getduty(varid) == MasterRepPricingVar 
        subprob = find_owner_formulation(form.parent_formulation, var)
        cur_sp_ub = unit.cur_sp_upper_bounds[getuid(subprob)]
        if update_lower_bound!(
                algo, unit, getvar(subprob, varid), subprob,
                getcurlb(form, varid) - (max(cur_sp_ub, 1) - 1) * getcurub(subprob, varid)
            )
            return true
        end
    elseif getduty(varid) == DwSpPricingVar
        master = form.parent_formulation
        cur_sp_lb = unit.cur_sp_lower_bounds[getuid(form)]
        mastervar = getvar(master, varid)
        if update_lower_bound!(
                algo, unit, mastervar, master, getcurlb(form, varid) * cur_sp_lb
            )
            return true
        end
        new_ub_in_sp = (
            getcurub(master, varid) - (max(cur_sp_lb, 1) - 1) * getcurlb(form, varid)
        )
        if update_upper_bound!(algo, unit, mastervar, form, new_ub_in_sp)
            return true
        end
    end

    return false
end

function update_upper_bound!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, var::Variable, 
    form::Formulation{Duty}, new_ub::Float64
    ) where {Duty}
    varid = getid(var)
    if Duty == DwSp
        if !algo.preprocess_subproblems || unit.cur_sp_upper_bounds[getuid(form)] == 0
            return false
        end
    end
    cur_lb = getcurlb(form, varid)
    cur_ub = getcurub(form, varid)
    new_ub >= cur_ub  && return false
    
    algo.printing && println(IOContext(stdout, :compact => true),
       "Upper bound of var ", getname(form, varid), " of type ", getduty(varid), 
        " in ", form, " is changed from ", cur_ub, " to ", new_ub, 
    )

    if new_ub < cur_lb 
        if Duty == DwSp && unit.cur_sp_upper_bounds[getuid(form)] == 0
            change_sp_upper_bound!(algo, unit, form, 0, update_global_var_bounds = true)
            return false
        else    
            return true
        end
    end

    diff = cur_ub == Inf ? -new_ub : cur_ub - new_ub
    coef_matrix = getcoefmatrix(form)
    for (constrid, coef) in @view coef_matrix[:, varid]
        iscuractive(form, constrid) || continue
        isexplicit(form, constrid) || continue
        getduty(constrid) != MasterConvexityConstr || continue
        infeasible = false
        if coef > 0 
            infeasible = update_min_slack!(
                algo, unit, constrid, form, cur_ub == Inf , diff * coef
            )
        else
            infeasible = update_max_slack!(
                algo, unit, constrid, form, cur_ub == Inf , diff * coef
            )
        end
        infeasible && return true
    end

    setcurub!(form, varid, new_ub)
    if Duty == DwSp && (varid,form) ∉ unit.sp_vars_with_changed_bounds
        push!(unit.sp_vars_with_changed_bounds, (varid,form))
    end
    
    # Now we update bounds of clones
    if getduty(varid) == MasterRepPricingVar 
        subprob = find_owner_formulation(form.parent_formulation, var)
        cur_sp_lb = unit.cur_sp_lower_bounds[getuid(subprob)]
        if update_upper_bound!(
            algo, unit, getvar(subprob, varid), subprob,
            getcurub(form, varid) - (max(cur_sp_lb, 1) - 1) * getcurlb(subprob, varid)
            )
            return true
        end
    elseif getduty(varid) == DwSpPricingVar
        master = form.parent_formulation
        cur_sp_ub = unit.cur_sp_upper_bounds[getuid(form)]
        clone_var_in_master = getvar(master, varid)
        if update_upper_bound!(
            algo, unit, clone_var_in_master, master, getcurub(form, varid) * cur_sp_ub
            )
            return true
        end
        new_lb_in_sp = (
            getcurlb(master, varid) - (max(cur_sp_ub, 1) - 1) * getcurub(form, varid)
            )
        if update_lower_bound!(algo, unit, clone_var_in_master, master, new_lb_in_sp)
            return true
        end
    end

    return false
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

function strengthen_var_bounds_in_constr!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, constrid::ConstrId, form::Formulation{Duty}
    ) where {Duty}
    if Duty == DwSp
        if !algo.preprocess_subproblems || unit.cur_sp_upper_bounds[getuid(form)] == 0
            return false
        end
    end

    if getduty(constrid) <= AbstractMasterConstr
        var_filter = (varid -> isanOriginalRepresentatives(getduty(varid)))
    else
        var_filter = (varid -> (getduty(varid) == DwSpPricingVar))
    end
    coef_matrix = getcoefmatrix(form)
    for (varid, coef) in @view coef_matrix[constrid,:]
        var_filter(varid) || continue

        if coef > 0 && getcursense(form, constrid) == Less
            new_bound_is_upper = true
            new_bound = compute_new_bound(
                    unit.nb_inf_sources_for_max_slack[constrid],
                    unit.cur_max_slack[constrid], -coef * getcurlb(form, varid), Inf, coef
                    )
        elseif coef > 0 && getcursense(form, constrid) != Less
            new_bound_is_upper = false
            new_bound = compute_new_bound(
                    unit.nb_inf_sources_for_min_slack[constrid],
                    unit.cur_min_slack[constrid], -coef * getcurub(form, varid), -Inf, coef
                    )
        elseif coef < 0 && getcursense(form, constrid) != Greater
            new_bound_is_upper = false
            new_bound = compute_new_bound(
                    unit.nb_inf_sources_for_max_slack[constrid],
                    unit.cur_max_slack[constrid], -coef * getcurub(form, varid), -Inf, coef
                    )
        else
            new_bound_is_upper = true
            new_bound = compute_new_bound(
                    unit.nb_inf_sources_for_min_slack[constrid], 
                    unit.cur_min_slack[constrid], -coef * getcurlb(form, varid), Inf, coef
                    )
        end
    
        if !isinf(new_bound)
            if getcurkind(form, varid) != Continuous 
                new_bound = new_bound_is_upper ? floor(new_bound) : ceil(new_bound)
            end
            infeasible = false
            if new_bound_is_upper
                infeasible = update_upper_bound!(algo, unit, getvar(form, varid), form, new_bound)
            else
                infeasible = update_lower_bound!(algo, unit, getvar(form, varid), form, new_bound)
            end
            infeasible && return true
        end
    end
    return false
end

function propagation!(algo::PreprocessAlgorithm, unit::PreprocessingUnit)
    while !isempty(unit.stack)
        (constrid, form) = pop!(unit.stack)
        delete!(unit.constrs_in_stack, constrid)
        
        # if algo.printing
        #     println("constr ", getname(form, constr), " ", typeof(constr), " popped")
        #     println(
        #         "rhs ", getcurrhs(form, constr), " max: ",
        #         alg_data.cur_max_slack[getid(constr)], " min: ",
        #         alg_data.cur_min_slack[getid(constr)]
        #     )
        # end
        if strengthen_var_bounds_in_constr!(algo, unit, constrid, form)

            return true
        end
    end
    return false
end

# TO DO : for the moment, this is not the most efficient implementation
# a more efficient one would involve unit.sp_vars_with_changed_bounds
# and we need to quickly access columns generated by a subproblem (to access them
# if a lower bound of sp variables becomes larger than zero)
function forbid_infeasible_columns!(
    algo::PreprocessAlgorithm, unit::PreprocessingUnit, master::Formulation{DwMaster}
    )
    num_deactivated_columns = 0
    for (col_id, col) in getvars(master)
        iscuractive(master, col_id) || continue
        getduty(col_id) <= MasterCol || continue
        
        spuid = getoriginformuid(col_id)
        if unit.cur_sp_upper_bounds[spuid] == 0
            deactivate!(master,col_id)
            num_deactivated_columns += 1
            continue
        end

        spform = get_dw_pricing_sps(master.parent_formulation)[spuid]
        for (repid, repval) in @view get_primal_sol_pool(spform)[:,col_id]
            if !(getcurlb(spform, repid) <= repval <= getcurub(spform, repid))
                deactivate!(master,col_id)
                num_deactivated_columns += 1
                continue
            end
        end
    end

    if num_deactivated_columns > 0
        @logmsg LogLevel(0) "Preprocessing deactivated $num_deactivated_columns columns"
    end

    return
end

function remove_preprocessed_constraints(algo::PreprocessAlgorithm, unit::PreprocessingUnit)

    num_deactivated_constraints = 0
    for (constrid, form) in unit.preprocessed_constrs
        iscuractive(form, constrid) || continue
        deactivate!(form, constrid)
        num_deactivated_constraints += 1
    end

    if num_deactivated_constraints > 0
        @logmsg LogLevel(0) "Preprocessing deactivated $num_deactivated_constraints constraints"
    end

    return
end

struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
    deactivated_constrs::Vector{ConstrId}
    fixed_variables::Dict{VarId, Float64}
end

mutable struct DwPresolveReform
    original_master::PresolveFormulation
    restricted_master::PresolveFormulation
    dw_sps::Dict{FormId, PresolveFormulation}
end

function create_presolve_form(
    form::Formulation,
    keep_var::Function,
    keep_constr::Function;
    lower_multiplicity = 1, 
    upper_multiplicity = 1
)
    sm_constr_ids, sm_var_ids, nz = _submatrix_nz_elems(form, keep_constr, keep_var)

    constr_ids = Set{ConstrId}()
    for (constr_id, constr) in getconstrs(form)
        if keep_constr(form, constr_id, constr)
            push!(constr_ids, constr_id)
        end
    end

    var_ids = Set{VarId}()
    for (var_id, var) in getvars(form)
        if keep_var(form, var_id, var)
            push!(var_ids, var_id)
        end
    end

    var_to_col = Dict{VarId,Int64}()
    col_to_var = Variable[]
    for (k, varid) in enumerate(unique(var_ids))
        var = getvar(form, varid)
        @assert !isnothing(var)
        push!(col_to_var, var)
        var_to_col[varid] = k
    end

    constr_to_row = Dict{ConstrId,Int64}()
    row_to_constr = Constraint[]
    for (k, constrid) in enumerate(unique(constr_ids))
        constr = getconstr(form, constrid)
        @assert !isnothing(constr)
        push!(row_to_constr, constr)
        constr_to_row[constrid] = k
    end

    coef_submatrix = sparse(
        map(constr_id -> constr_to_row[constr_id], sm_constr_ids),
        map(var_id -> var_to_col[var_id], sm_var_ids),
        nz,
        length(row_to_constr),
        length(col_to_var),
    )

    lbs_vals = Float64[]
    ubs_vals = Float64[]
    partial_sol = Float64[]
    for var in col_to_var
        push!(lbs_vals, getcurlb(form, var))
        push!(ubs_vals, getcurub(form, var))
        @assert !isnan(getcurlb(form, var))
        @assert !isnan(getcurub(form, var))
        #push!(partial_sol, MathProg.get_value_in_partial_sol(form, var))
        push!(partial_sol, 0.0)
    end

    rhs_vals = Float64[]
    sense_vals = Coluna.ConstrSense[]
    for constr in row_to_constr
        push!(rhs_vals, getcurrhs(form, constr))
        push!(sense_vals, getcursense(form, constr))
    end

    form = PresolveFormRepr(
        coef_submatrix,
        rhs_vals,
        sense_vals,
        lbs_vals,
        ubs_vals,
        partial_sol,
        lower_multiplicity,
        upper_multiplicity
    )

    deactivated_constrs = ConstrId[]

    return PresolveFormulation(
        col_to_var,
        row_to_constr,
        var_to_col,
        constr_to_row,
        form,
        deactivated_constrs,
        Dict{VarId, Float64}()
    )
end

function propagate_in_presolve_form(
    form::PresolveFormulation,
    rows_to_deactivate::Vector{Int},
    tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}};
    tighten_bounds = true,
    partial_sol = true,
    shrink = true,
    store_unpropagated_partial_sol = true
)
    form_repr, row_mask, col_mask, fixed_vars = PresolveFormRepr(
        form.form, 
        rows_to_deactivate, 
        tightened_bounds, 
        form.form.lower_multiplicity, 
        form.form.upper_multiplicity;
        tighten_bounds = tighten_bounds,
        partial_sol = partial_sol,
        shrink = shrink,
        store_unpropagated_partial_sol = store_unpropagated_partial_sol
    )

    col_to_var = form.col_to_var[col_mask]
    row_to_constr = form.row_to_constr[row_mask]

    deactivated_constrs = form.deactivated_constrs
    fixed_vars_dict = form.fixed_variables

    var_to_col = Dict(getid(var) => k for (k, var) in enumerate(col_to_var))
    constr_to_row = Dict(getid(constr) => k for (k, constr) in enumerate(row_to_constr))

    if shrink
        for constr in form.row_to_constr[.!row_mask]
            push!(deactivated_constrs, getid(constr))
        end

        if !isnothing(fixed_vars)
            for (col, val) in fixed_vars
                varid = getid(form.col_to_var[col])
                if !haskey(fixed_vars_dict, varid)
                    fixed_vars_dict[varid] = val
                else
                    error("Cannot fix variable twice.")
                end
            end
        end
    end

    @assert length(col_to_var) == length(form_repr.lbs)
    @assert length(col_to_var) == length(form_repr.ubs)
    @assert length(row_to_constr) == length(form_repr.rhs)

    return PresolveFormulation(
        col_to_var,
        row_to_constr, 
        var_to_col,
        constr_to_row,
        form_repr,
        deactivated_constrs,
        fixed_vars_dict
    )
end

function create_presolve_reform(reform::Reformulation{DwMaster})
    master = getmaster(reform)
    # Create the presolve formulations
    # Master 1:
    #     Variables: subproblem representatives & master pure 
    #     Constraints: master pure & master mixed & branching constraints & cuts
    original_master_vars = (form, varid, var) -> (
        (getduty(varid) <= MasterPureVar && iscuractive(form, var)) || 
        getduty(varid) <= MasterRepPricingVar
    )
    original_master_constrs = (form, constrid, constr) -> (
        iscuractive(form, constr) && (
            getduty(constrid) <= MasterPureConstr ||
            getduty(constrid) <= MasterMixedConstr ||
            getduty(constrid) <= MasterBranchOnOrigVarConstr ||
            getduty(constrid) <= MasterUserCutConstr ||
            getduty(constrid) <= MasterConvexityConstr
        )
    )
    original_master = create_presolve_form(master, original_master_vars, original_master_constrs)

    # Master 2:
    #     Variables: columns & master pure & artifical variables
    #     Constraints: master pure & master mixed & convexity constraints & branching constraints & cuts
    restricted_master_vars = (form, varid, var) -> (
        iscuractive(form, var) && (
            getduty(varid) <= MasterPureVar ||
            getduty(varid) <= MasterCol ||
            getduty(varid) <= MasterArtVar
        )
    )
    restricted_master_constrs = (form, constrid, constr) -> (
        iscuractive(form, constr) && (
            getduty(constrid) <= MasterPureConstr ||
            getduty(constrid) <= MasterMixedConstr ||
            getduty(constrid) <= MasterBranchOnOrigVarConstr ||
            getduty(constrid) <= MasterUserCutConstr ||
            getduty(constrid) <= MasterConvexityConstr
        )
    )
    restricted_master = create_presolve_form(master, restricted_master_vars, restricted_master_constrs)

    # Subproblems:
    #     Variables: pricing variables
    #     Constraints: DwSpPureConstr
    sp_vars = (form, varid, var) -> iscuractive(form, var) && getduty(varid) <= DwSpPricingVar
    sp_constrs = (form, constrid, constr) -> iscuractive(form, constr) && getduty(constrid) <= DwSpPureConstr

    master_repr_lb_ub = Dict{VarId, Tuple{Float64,Float64}}()

    dw_sps = Dict{FormId, PresolveFormulation}()
    for (spid, sp) in get_dw_pricing_sps(reform)
        lm = getcurrhs(master, sp.duty_data.lower_multiplicity_constr_id)
        um = getcurrhs(master, sp.duty_data.upper_multiplicity_constr_id)

        dw_sps[spid] = create_presolve_form(sp, sp_vars, sp_constrs, lower_multiplicity = lm, upper_multiplicity = um)
        
        # Update bounds on master repr variables using multiplicity.
        for (varid, var) in getvars(sp)
            if getduty(varid) <= DwSpPricingVar
                lb = getcurlb(sp, var)
                ub = getcurub(sp, var)
                
                (global_lb, global_ub) = get(master_repr_lb_ub, varid, (0.0, 0.0))
                global_lb += (lb > 0 ? lm : um) * lb
                global_ub += (ub > 0 ? um : lm) * ub
            
                master_repr_lb_ub[varid] = (global_lb, global_ub)
            end
        end
    end

    for (varid, (lb, ub)) in master_repr_lb_ub
        var_col = original_master.var_to_col[varid]
        @assert !isnan(lb)
        @assert !isnan(ub)
        original_master.form.lbs[var_col] = lb
        original_master.form.ubs[var_col] = ub
    end
    return DwPresolveReform(original_master, restricted_master, dw_sps)
end

function _update_partial_sol!(form::Formulation{DwMaster}, presolve_form::PresolveFormulation)
    # Update partial solution
    partial_sol_counter = 0
    for (col, val) in enumerate(presolve_form.form.partial_solution)
        var = presolve_form.col_to_var[col]
        if getduty(getid(var)) <= MasterArtVar && !iszero(val)
            error(""" Infeasible because artificial variable $(getname(form, var)) is not zero.
            Fixed to $(val) in partial solution.
            """)
        end
        if !iszero(val)
            MathProg.add_to_partial_solution!(form, var, val)
            partial_sol_counter += 1
        end
    end
    return
end

_update_partial_sol!(form, presolve_form) = nothing

function _update_bounds!(form::Formulation, presolve_form::PresolveFormulation)
     # Update bounds
     for (col, (lb, ub)) in enumerate(Iterators.zip(
        presolve_form.form.lbs,
        presolve_form.form.ubs
    ))
        @assert !isnan(lb)
        @assert !isnan(ub)
        var = presolve_form.col_to_var[col]

        if getduty(getid(var)) <= MasterCol
            @assert iszero(lb)
            setcurlb!(form, var, 0.0)
            # ignore the upper bound (we keep Inf)
        else
            setcurlb!(form, var, lb)
            setcurub!(form, var, ub)
        end
    end
    return
end

# function _update_convexity_constr!(master::Formulation{DwMaster}, sp_presolve_form, sp::Formulation{DwSp})
#     lm_constr = getconstr(master, sp.duty_data.lower_multiplicity_constr_id)
#     um_constr = getconstr(master, sp.duty_data.upper_multiplicity_constr_id)

#     @assert !isnothing(lm_constr) && !isnothing(um_constr)

#     lm = sp_presolve_form.form.lower_multiplicity
#     um = sp_presolve_form.form.upper_multiplicity

#     setcurrhs!(master, lm_constr, max(lm, 0))
#     setcurrhs!(master, um_constr, max(um, 0))
#     return
# end

function _update_rhs!(form::Formulation, presolve_form::PresolveFormulation)
    for (row, rhs) in enumerate(presolve_form.form.rhs)
        constr = presolve_form.row_to_constr[row]
        if getduty(getid(constr)) <= MasterConvexityConstr
            if getcursense(form, constr) == Less
                setcurrhs!(form, constr, max(rhs, 0))
            elseif getcursense(form, constr) == Greater
                setcurrhs!(form, constr, max(rhs, 0))
            end
        else
            setcurrhs!(form, constr, rhs)
        end
    end
    return
end

function update_form_from_presolve!(
    form::Formulation, presolve_form::PresolveFormulation;
    update_rhs = true,
    update_partial_sol = true,
)
    # Deactivate Constraints
    constr_deactivation_counter = 0
    for constr_id in presolve_form.deactivated_constrs
        if iscuractive(form, getconstr(form, constr_id))
            deactivate!(form, getconstr(form, constr_id))
            constr_deactivation_counter += 1
        end
    end

    # Fixed variables
    var_fix_counter = 0
    for (var_id, val) in presolve_form.fixed_variables
        if iscuractive(form, var_id)
            setcurlb!(form, var_id, 0.0)
            setcurub!(form, var_id, 0.0)
            MathProg.add_to_partial_solution!(form, var_id, val)
            deactivate!(form, var_id)
            var_fix_counter += 1
        end
    end

    if update_rhs
        _update_rhs!(form, presolve_form)
    end

    _update_bounds!(form, presolve_form)

    if update_partial_sol
        _update_partial_sol!(form, presolve_form)
    end
    return
end

function update_reform_from_presolve!(
    master::Formulation{DwMaster}, 
    dw_pricing_sps::Dict,
    presolve_reform::DwPresolveReform
)
    # Update master
    presolve_restr_master = presolve_reform.restricted_master
    update_form_from_presolve!(master, presolve_restr_master)

    # Update subproblems
    for (spid, sp) in dw_pricing_sps
        sp_presolve_form = presolve_reform.dw_sps[spid]
        update_form_from_presolve!(sp, sp_presolve_form)
    end

    presolve_repr_master = presolve_reform.original_master
    update_form_from_presolve!(
        master, presolve_repr_master;
        update_partial_sol = false,
        update_rhs = false
    )
    return
end

"""
Presolve algorithm
"""
struct PresolveAlgorithm <: AlgoAPI.AbstractAlgorithm
    ϵ::Float64
    PresolveAlgorithm(;ϵ = Coluna.TOL) = new(ϵ)
end

# PresolveAlgorithm does not have child algorithms, therefore get_child_algorithms() is not defined
function get_units_usage(algo::PresolveAlgorithm, reform::Reformulation) 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[]
    master = getmaster(reform)
    push!(units_usage, (master, StaticVarConstrUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterBranchConstrsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterCutsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterColumnsUnit, READ_AND_WRITE))
    for (_, dw_sp) in get_dw_pricing_sps(reform)
        push!(units_usage, (dw_sp, StaticVarConstrUnit, READ_AND_WRITE))
    end
    return units_usage
end

struct PresolveInput
    partial_sol_to_fix::Dict{VarId, Float64}
    # may be instead?
    #partial_sol_to_fix::MathProg.PrimalSolution{Formulation{MasterDuty}}
end

struct PresolveOutput 
    feasible::Bool
end

function propagate_partial_sol_into_master(presolve_reform, dw_pricing_sps)
    # Step 1 (before main loop):
    # Create the partial solution
    new_restr_master = propagate_in_presolve_form(
        presolve_reform.restricted_master,
        Int[], # we don't perform constraint deactivation
        Dict{Int, Tuple{Float64, Bool, Float64, Bool}}(); # we don't perform bound tightening on the restricted master.
        tighten_bounds = false,
        shrink = false
    )
    presolve_reform.restricted_master = new_restr_master

    # Step 2: Propagate the partial solution to the local bounds.
    propagate_partial_sol_to_repr_master!(
        dw_pricing_sps,
        presolve_reform
    )

    new_repr_master = propagate_in_presolve_form(
        presolve_reform.original_master, 
        Int[], 
        Dict{Int, Tuple{Float64, Bool, Float64, Bool}}(); 
        tighten_bounds = false,
        shrink = false,
        store_unpropagated_partial_sol = false
    )
    presolve_reform.original_master = new_repr_master

    # The right rhs is the one from the restricted master because the master may
    # contain non-robust cuts.
    @assert length(presolve_reform.restricted_master.form.rhs) == length(presolve_reform.original_master.form.rhs)
    for (row, rhs) in enumerate(presolve_reform.restricted_master.form.rhs)
        presolve_reform.original_master.form.rhs[row] = rhs
    end
end

function presolve_iteration!(presolve_reform, master, dw_pricing_sps)
    # Step 5: Propagate and strengthen local and global bounds.
    propagate_global_to_local_bounds!(master, dw_pricing_sps, presolve_reform)
    propagate_local_to_global_bounds!(master, dw_pricing_sps, presolve_reform)
    propagate_global_to_local_bounds!(master, dw_pricing_sps, presolve_reform)
    propagate_local_to_global_bounds!(master, dw_pricing_sps, presolve_reform)

    # Step 3: presolve the respresentative master.
    # Bounds tightening, we do not shrink the formulation.
    tightened_bounds_repr = bounds_tightening(presolve_reform.original_master.form)
    new_repr_master = propagate_in_presolve_form(
        presolve_reform.original_master, 
        Int[], 
        
        tightened_bounds_repr; shrink = false
    )

    presolve_reform.original_master = new_repr_master

    # Step 6: Shrink the formulation (remove fixed variables).
    new_restr_master = propagate_in_presolve_form(
        presolve_reform.restricted_master,
        Int[],
        Dict{Int, Tuple{Float64, Bool, Float64, Bool}}();
        tighten_bounds = false,
        partial_sol = false
    )
    
    presolve_reform.restricted_master = new_restr_master
    return
end

function run!(algo::PresolveAlgorithm, ::Env, reform::Reformulation, input::PresolveInput)::PresolveOutput

    # Should be move in the diving (when generating the formulation of the children because
    # formulation is the single source of truth).
    for (varid, val) in input.partial_sol_to_fix
        if MathProg.getduty(varid) <= MasterCol
            MathProg.setcurlb!(getmaster(reform), varid, val)
        else # especially for MasterPureVar
            MathProg.setcurlb!(getmaster(reform), varid, val)
            MathProg.setcurub!(getmaster(reform), varid, val)
        end
    end

    presolve_reform = create_presolve_reform(reform)

    propagate_partial_sol_into_master(presolve_reform, get_dw_pricing_sps(reform))

    for i in 1:3
        println("**** Presolve step $i ****")
        presolve_iteration!(presolve_reform, getmaster(reform), get_dw_pricing_sps(reform))
    end

    update_reform_from_presolve!(
        getmaster(reform), 
        get_dw_pricing_sps(reform), 
        presolve_reform
    )
    return PresolveOutput(true)
end

function _column_is_proper(col_id, sp_form)
    # Retrieve the column in the pool.
    pool = get_primal_sol_pool(sp_form)
    solution = @view pool.solutions[col_id, :]

    for (var_id, value) in solution
        if value < getcurlb(sp_form, var_id) - Coluna.TOL || value > getcurub(sp_form, var_id) + Coluna.TOL
            return false
        end
    end
    return true
end


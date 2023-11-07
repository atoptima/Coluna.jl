"""
Stores a matrix-representation of the formulation and the mapping between the variables & 
constraints of the formulation to the row and column of the matrix and components of the 
vector that represents the formulation.
"""
struct PresolveFormulation
    col_to_var::Vector{Variable}
    row_to_constr::Vector{Constraint}
    var_to_col::Dict{VarId,Int64}
    constr_to_row::Dict{ConstrId,Int64}
    form::PresolveFormRepr
    deactivated_constrs::Vector{ConstrId}
    fixed_variables::Dict{VarId, Float64}
end

"""
Stores the presolve-representation of the formulations of the Dantzig-Wolfe reformulation.
This datastructure contains:

- `representative_master` that contains the master formulation expressed with representative
  variables and pure master variables
- `restricted_master` that contains the master formulation expressed with pure master variables,
   master columns, and artificial variables
- `dw_sps` a dictionary that contains the subproblem formulations.
"""
mutable struct DwPresolveReform
    representative_master::PresolveFormulation
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
    tightened_bounds::Dict{Int, Tuple{Float64, Bool, Float64, Bool}}
)
    form_repr, row_mask, col_mask = PresolveFormRepr(
        form.form, 
        rows_to_deactivate, 
        tightened_bounds, 
        form.form.lower_multiplicity, 
        form.form.upper_multiplicity
    )

    col_to_var = form.col_to_var[col_mask]
    row_to_constr = form.row_to_constr[row_mask]

    deactivated_constrs = form.deactivated_constrs
    fixed_vars_dict = form.fixed_variables

    var_to_col = Dict(getid(var) => k for (k, var) in enumerate(col_to_var))
    constr_to_row = Dict(getid(constr) => k for (k, constr) in enumerate(row_to_constr))

    for constr in form.row_to_constr[.!row_mask]
        push!(deactivated_constrs, getid(constr))
    end

    # if !isnothing(fixed_vars)
    #     for (col, val) in fixed_vars
    #         varid = getid(form.col_to_var[col])
    #         if !haskey(fixed_vars_dict, varid)
    #             fixed_vars_dict[varid] = val
    #         else
    #             error("Cannot fix variable twice.")
    #         end
    #     end
    # end
    
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

function update_partial_sol!(form::Formulation{DwMaster}, presolve_form::PresolveFormulation, partial_solution)
    # Update partial solution
    partial_sol_counter = 0
    for (col, val) in enumerate(partial_solution)
        var = presolve_form.col_to_var[col]
        duty = getduty(getid(var))
        if duty <= MasterArtVar && !iszero(val)
            error(""" Infeasible because artificial variable $(getname(form, var)) is not zero.
            Fixed to $(val) in partial solution.
            """)
        end
        if !iszero(val) && (duty <= MasterCol || duty <= MasterPureVar)
            MathProg.add_to_partial_solution!(form, var, val)
            partial_sol_counter += 1
            setcurlb!(form, var, 0.0)
        end
    end
    return
end

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

function update_form_from_presolve!(form::Formulation, presolve_form::PresolveFormulation)
    # Deactivate Constraints
    constr_deactivation_counter = 0
    for constr_id in presolve_form.deactivated_constrs
        if iscuractive(form, getconstr(form, constr_id))
            deactivate!(form, getconstr(form, constr_id))
            constr_deactivation_counter += 1
        end
    end

    # # Fixed variables
    # var_fix_counter = 0
    # for (var_id, val) in presolve_form.fixed_variables
    #     if iscuractive(form, var_id)
    #         setcurlb!(form, var_id, 0.0)
    #         setcurub!(form, var_id, 0.0)
    #         MathProg.add_to_partial_solution!(form, var_id, val)
    #         deactivate!(form, var_id)
    #         var_fix_counter += 1
    #     end
    # end

    _update_rhs!(form, presolve_form)
    _update_bounds!(form, presolve_form)
    return
end

function update_reform_from_presolve!(
    master::Formulation{DwMaster}, 
    dw_pricing_sps::Dict,
    presolve_reform::DwPresolveReform
)
    # Update subproblems
    for (spid, sp) in dw_pricing_sps
        sp_presolve_form = presolve_reform.dw_sps[spid]
        update_form_from_presolve!(sp, sp_presolve_form)
    end

    presolve_repr_master = presolve_reform.representative_master
    update_form_from_presolve!(master, presolve_repr_master)
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
    push!(units_usage, (master, PartialSolutionUnit, READ_AND_WRITE))
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

function _get_partial_sol(presolve_form_repr::PresolveFormRepr)
    new_partial_sol = zeros(Float64, length(presolve_form_repr.partial_solution))
    for (i, (lb, ub)) in  enumerate(Iterators.zip(presolve_form_repr.lbs, presolve_form_repr.ubs))
        @assert !isnan(lb)
        @assert !isnan(ub)
        if lb > ub
            error("Infeasible.")
        end
        if lb > 0.0
            @assert !isinf(lb)
            new_partial_sol[i] += lb
        elseif ub < 0.0 && !isinf(ub)
            @assert !isinf(ub)
            new_partial_sol[i] += ub
        end
    end
    return new_partial_sol
end

get_restr_partial_sol(presolve_form) = _get_partial_sol(presolve_form.form)

function compute_rhs(presolve_form, restr_partial_sol)
    rhs = presolve_form.form.rhs
    coef_matrix = presolve_form.form.col_major_coef_matrix
    return rhs - coef_matrix * restr_partial_sol
end

function update_subproblem_multiplicities!(dw_sps, nb_fixed_columns_per_sp)
    for (spid, presolve_sp) in dw_sps
        lm = presolve_sp.form.lower_multiplicity
        um = presolve_sp.form.upper_multiplicity

        presolve_sp.form.lower_multiplicity = max(0, lm - nb_fixed_columns_per_sp[spid])
        presolve_sp.form.upper_multiplicity = max(0, um - nb_fixed_columns_per_sp[spid]) # TODO if < 0 -> error
    end
    return
end

function propagate_partial_sol_to_global_bounds!(presolve_repr_master, local_repr_partial_sol, default_global_bounds)
    new_lbs = zeros(Float64, presolve_repr_master.form.nb_vars)
    new_ubs = zeros(Float64, presolve_repr_master.form.nb_vars)

    for (col, (val, lb, ub, (def_glob_lb, def_glob_ub))) in enumerate(
        Iterators.zip(
            local_repr_partial_sol,
            presolve_repr_master.form.lbs,
            presolve_repr_master.form.ubs,
            default_global_bounds
        )
    )
        new_lbs[col] = max(lb - val, def_glob_lb)
        new_ubs[col] = min(ub - val, def_glob_ub)
    end

    presolve_repr_master.form.lbs = new_lbs
    presolve_repr_master.form.ubs = new_ubs
    return
end

# You need to update subproblem multiplicity before using this function.
function compute_default_global_bounds(presolve_repr_master, presolve_dw_pricing_sps, master, dw_pricing_sps)
    global_bounds = Dict{VarId, Tuple{Float64,Float64}}()

    for (spid, sp) in dw_pricing_sps
        lm = presolve_dw_pricing_sps[spid].form.lower_multiplicity
        um = presolve_dw_pricing_sps[spid].form.upper_multiplicity
    
        # Update bounds on master repr variables using multiplicity.
        for (varid, var) in getvars(sp)
            if getduty(varid) <= DwSpPricingVar
                lb = getcurlb(sp, var)
                ub = getcurub(sp, var)
                
                (global_lb, global_ub) = get(global_bounds, varid, (0.0, 0.0))
                global_lb += (lb > 0 ? lm : um) * lb
                global_ub += (ub > 0 ? um : lm) * ub
            
                global_bounds[varid] = (global_lb, global_ub)
            end
        end
    end

    master_repr_var_bounds = [(-Inf, Inf) for _ in 1:presolve_repr_master.form.nb_vars]
    for (varid, bounds) in global_bounds 
        col = get(presolve_repr_master.var_to_col, varid, nothing)
        @assert !isnothing(col)
        master_repr_var_bounds[col] = bounds
    end
    return master_repr_var_bounds
end

"""


Returns the local restricted partial solution.
"""
function propagate_partial_sol_into_master!(presolve_reform, master, dw_pricing_sps)
    presolve_representative_master = presolve_reform.representative_master
    presolve_restricted_master = presolve_reform.restricted_master

    # Create the local partial solution from the restricted master presolve representation.
    # This local partial solution must then be "fixed" & propagated.
    local_restr_partial_sol = get_restr_partial_sol(presolve_restricted_master)

    # Compute the rhs of all constraints.
    # Non-robust and convexity constraints rhs can only be computed using this representation.
    new_rhs = compute_rhs(presolve_restricted_master, local_restr_partial_sol)

    # Project local partial solution on the representative master.
    local_repr_partial_sol, nb_fixed_columns_per_sp = partial_sol_on_repr(
        dw_pricing_sps, presolve_representative_master, presolve_restricted_master,
        local_restr_partial_sol
    )

    # Update the multiplicity of each subproblem.
    update_subproblem_multiplicities!(presolve_reform.dw_sps, nb_fixed_columns_per_sp)

    # Compute new default global bounds
    master_repr_default_global_bounds = compute_default_global_bounds(
        presolve_reform.representative_master, presolve_reform.dw_sps, master, dw_pricing_sps
    )

    # Propagate local partial solution from the representative master representation
    # into the global bounds.
    propagate_partial_sol_to_global_bounds!(
        presolve_reform.representative_master, 
        local_repr_partial_sol,
        master_repr_default_global_bounds
    )

    # Update the rhs of the representative master.
    @assert length(new_rhs) == length(presolve_reform.restricted_master.form.rhs) == length(presolve_reform.representative_master.form.rhs)
    for (row, rhs) in enumerate(new_rhs)
        presolve_reform.representative_master.form.rhs[row] = rhs
    end
    return local_restr_partial_sol
end

function presolve_iteration!(presolve_reform, master, dw_pricing_sps)
    # Propagate and strengthen local and global bounds.
    # At the moment, we perform two rounds of local/global bounds strenthening and propagation.
    propagate_global_to_local_bounds!(master, dw_pricing_sps, presolve_reform)
    propagate_local_to_global_bounds!(master, dw_pricing_sps, presolve_reform)
    propagate_global_to_local_bounds!(master, dw_pricing_sps, presolve_reform)
    propagate_local_to_global_bounds!(master, dw_pricing_sps, presolve_reform)

    # Presolve the respresentative master.
    # Bounds tightening, we do not change 
    tightened_bounds_repr = bounds_tightening(presolve_reform.representative_master.form)
    new_repr_master = propagate_in_presolve_form(
        presolve_reform.representative_master, 
        Int[],
        tightened_bounds_repr
    )

    presolve_reform.representative_master = new_repr_master
    return
end

function deactivate_non_proper_columns!(master::Formulation{DwMaster}, dw_sps)
    for (varid, var) in getvars(master)
        if getduty(varid) <= MasterCol
            spid = getoriginformuid(varid)
            if !_column_is_proper(varid, dw_sps[spid])
                deactivate!(master, varid)
            end
        end
    end
    return
end

function _presolve_run!(presolve_reform, master, dw_pricing_sps)
    # Identify the partial solution in the restricted master, compute the new rhs
    # of all master constraints and new global and local bounds of the representative and 
    # subproblem variables.
    local_restr_partial_sol = propagate_partial_sol_into_master!(
        presolve_reform,
        master,
        dw_pricing_sps
    )

    # Perform several rounds of presolve.
    for i in 1:3
        println("**** Presolve step $i ****")
        presolve_iteration!(presolve_reform, master, dw_pricing_sps)
    end

    update_partial_sol!(
        master,
        presolve_reform.restricted_master,
        local_restr_partial_sol
    )

    update_reform_from_presolve!(
        master, 
        dw_pricing_sps, 
        presolve_reform
    )

    deactivate_non_proper_columns!(master, dw_pricing_sps)
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
    master = getmaster(reform)
    dw_pricing_sps = get_dw_pricing_sps(reform)

    _presolve_run!(
        presolve_reform,
        master,
        dw_pricing_sps
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

function column_is_proper(col_id, reform)
    sp_id = getoriginformuid(col_id)
    sp_form = get_dw_pricing_sps(reform)[sp_id]
    return _column_is_proper(col_id, sp_form)
end

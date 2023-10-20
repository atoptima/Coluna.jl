###########################################################################################
# Propagation between formulations or a reformulation.
###########################################################################################

# Constraints deactivation propagates only from the original formulation to the master
# and subproblems.
# Indeed, there is no addition of constraints in the master formulation that changes the 
# original formulation. Same in the subproblems.
# Master and subproblems do not share any constraints.
function propagation_of_constraint_deactivation!(reform::DwPresolveReform)
    # Original -> Representatives Master

    # Original -> Subproblem

    return
end

function _prop_constr_deactivation!(original, master, original_rows_deactivated)

end

# Variables bounds propagate:
# - from the original formulation to the master and subproblems.
# - from the master to the subproblems when we perform variable bounds
# tightening on the representatives and the pure master variables.
# - from the subproblems to the master when we perform variable bounds
# tightening on subproblem variables.
function propagate_var_bounds_from!(dest::PresolveFormulation, src::PresolveFormulation)
    # Look at common variables.
    common_var_ids = intersect(keys(src.var_to_col), keys(dest.var_to_col))

    for var_id in common_var_ids
        src_col = src.var_to_col[var_id]
        dest_col = dest.var_to_col[var_id]
        dest_lb = src.form.lbs[src_col]
        dest_ub = src.form.ubs[src_col]
        @assert !isnan(dest_lb)
        @assert !isnan(dest_ub)
        dest.form.lbs[dest_col] = dest_lb
        dest.form.ubs[dest_col] = dest_ub
    end

    # Look at fixed variable
    common_var_ids = intersect(keys(src.fixed_variables), keys(dest.var_to_col))

    for var_id in common_var_ids
        src_var_val = src.fixed_variables[var_id]
        dest_col = dest.var_to_col[var_id]
        dest_lb = dest.form.partial_solution[dest_col]
        dest_ub = dest.form.partial_solution[dest_col]
        @assert !isnan(dest_lb)
        @assert !isnan(dest_ub)
        dest.form.lbs[dest_col] = src_var_val - dest.form.partial_solution[dest_col]
        dest.form.ubs[dest_col] = src_var_val - dest.form.partial_solution[dest_col]
    end
    return
end

function propagate_local_to_global_bounds!(
    master::Formulation{DwMaster}, 
    dw_pricing_sps::Dict,
    presolve_reform_repr::DwPresolveReform
)
    presolve_repr_master = presolve_reform_repr.original_master
    for (spid, spform) in dw_pricing_sps
        presolve_sp = presolve_reform_repr.dw_sps[spid]
        propagate_global_bounds!(presolve_repr_master, master, presolve_sp, spform)
    end
    return
end

function propagate_global_bounds!(presolve_repr_master::PresolveFormulation, master::Formulation, presolve_sp::PresolveFormulation, spform::Formulation)
    # TODO: does not work with representatives of multiple subproblems.
    lm = presolve_sp.form.lower_multiplicity
    um = presolve_sp.form.upper_multiplicity
    for (i, var) in enumerate(presolve_sp.col_to_var)
        repr_col = get(presolve_repr_master.var_to_col, getid(var), nothing)
        if !isnothing(repr_col)
            local_lb = presolve_sp.form.lbs[i]
            local_ub = presolve_sp.form.ubs[i]
            global_lb = presolve_repr_master.form.lbs[repr_col]
            global_ub = presolve_repr_master.form.ubs[repr_col]
            new_global_lb = local_lb * (local_lb < 0 ? um : lm)
            new_global_ub = local_ub * (local_ub < 0 ? lm : um)
            presolve_repr_master.form.lbs[repr_col] = max(global_lb, new_global_lb)
            presolve_repr_master.form.ubs[repr_col] = min(global_ub, new_global_ub)
        end
    end
    return
end

function propagate_global_to_local_bounds!(
    master::Formulation{DwMaster}, 
    dw_pricing_sps::Dict,
    presolve_reform_repr::DwPresolveReform
)
    presolve_repr_master = presolve_reform_repr.original_master
    for (spid, spform) in dw_pricing_sps
        presolve_sp = presolve_reform_repr.dw_sps[spid]
        propagate_local_bounds!(presolve_repr_master, master, presolve_sp, spform)
    end
    return
end

function propagate_local_bounds!(presolve_repr_master::PresolveFormulation, master::Formulation, presolve_sp::PresolveFormulation, spform::Formulation)
    # TODO: does not work with representatives of multiple subproblems.
    lm = presolve_sp.form.lower_multiplicity
    um = presolve_sp.form.upper_multiplicity
    for (i, var) in enumerate(presolve_sp.col_to_var)
        repr_col = get(presolve_repr_master.var_to_col, getid(var), nothing)
        if !isnothing(repr_col)
            global_lb = presolve_repr_master.form.lbs[repr_col]
            global_ub = presolve_repr_master.form.ubs[repr_col]
            local_lb = presolve_sp.form.lbs[i]
            local_ub = presolve_sp.form.ubs[i]

            if !isinf(global_lb) && !isinf(local_ub)
                new_local_lb = global_lb - local_ub * (local_ub > 0 ? um : lm)
                presolve_sp.form.lbs[i] = max(new_local_lb, local_lb)
            end

            if !isinf(global_ub) && !isinf(local_lb)
                new_local_ub = global_ub - local_lb * (local_lb > 0 ? lm : um)
                presolve_sp.form.ubs[i] = min(new_local_ub, local_ub)
            end
        end
    end
    return
end

function propagate_partial_sol_to_global_bounds!(presolve_sp::PresolveFormulation, presolve_master::PresolveFormulation, spform::Formulation, master::Formulation)
    partial_solution = zeros(Float64, presolve_sp.form.nb_vars)
    
    # Get new columns in partial solution.
    pool = get_primal_sol_pool(spform)

    # Get new columns in partial solution.
    nb_fixed_columns = 0
    new_column_explored = true
    for (col, partial_sol_value) in enumerate(presolve_master.form.unpropagated_partial_solution)
        if abs(partial_sol_value) > Coluna.TOL
            var = presolve_master.col_to_var[col]
            varid = getid(var)
            column = @view pool.solutions[varid,:]
            for (varid, val) in column
                getduty(varid) <= DwSpPricingVar || continue
                sp_var_col = presolve_sp.var_to_col[varid]
                partial_solution[sp_var_col] += val * partial_sol_value
                if new_column_explored
                    nb_fixed_columns += partial_sol_value
                    new_column_explored = false
                end
            end
        end
        new_column_explored = true
    end
    return
end

function partial_sol_on_repr(
    dw_pricing_sps::Dict, 
    presolve_reform_repr::DwPresolveReform,
    restr_partial_sol
)
    presolve_master_repr = presolve_reform_repr.original_master
    partial_solution = zeros(Float64, presolve_master_repr.form.nb_vars)

    # partial solution
    presolve_master_restr = presolve_reform_repr.restricted_master

    dw_pricing_sps = dw_pricing_sps
    nb_fixed_columns = Dict(spid => 0 for (spid, _) in dw_pricing_sps)
    new_column_explored = false
    for (col, partial_sol_value) in enumerate(restr_partial_sol)
        if abs(partial_sol_value) > Coluna.TOL
            var = presolve_master_restr.col_to_var[col]
            varid = getid(var)
            spid = getoriginformuid(varid)
            spform = get(dw_pricing_sps, spid, nothing)
            @assert !isnothing(spform)
            column = @view get_primal_sol_pool(spform).solutions[varid,:]
            for (varid, val) in column
                getduty(varid) <= DwSpPricingVar || continue
                master_repr_var_col = get(presolve_master_repr.var_to_col, varid, nothing)
                if !isnothing(master_repr_var_col)
                    partial_solution[master_repr_var_col] += val * partial_sol_value
                end
                if !new_column_explored
                    nb_fixed_columns[spid] += partial_sol_value
                    new_column_explored = true
                end
            end
            new_column_explored = false
        end
    end
    return partial_solution, nb_fixed_columns
end

function propagate_partial_sol_to_global_bounds!(presolve_repr_master, local_repr_partial_sol)
    new_lbs = zeros(Float64, presolve_repr_master.form.nb_vars)
    new_ubs = zeros(Float64, presolve_repr_master.form.nb_vars)

    # when there is a partial solution, we update the bound so that the lower bound
    # on the absolute value of the variable is improved.
    # Examples:
    # -3 <= x <= 3  &  x = 2    ->    2 <= x <= 3
    # -3 <= x <= 3  &  x = -1   ->   -3 <= x <= -1
    #  2 <= x <= 4  &  x = 3    ->    3 <= x <= 4
    # -5 <= x <= 0  &  x = -2   ->   -5 <= x <= -2
    for (col, (val, lb, ub)) in enumerate(
        Iterators.zip(
            local_repr_partial_sol, 
            presolve_repr_master.form.lbs, 
            presolve_repr_master.form.ubs
        )
    )
        if val > 0
            new_lbs[col] = val
            new_ubs[col] = ub
        elseif val < 0
            new_lbs[col] = lb
            new_ubs[col] = val
        else
            new_lbs[col] = lb
            new_ubs[col] = ub
        end

        if new_lbs[col] > new_ubs[col]
            error("Infeasible.")
        end
    end

    presolve_repr_master.form.lbs = new_lbs
    presolve_repr_master.form.ubs = new_ubs

end
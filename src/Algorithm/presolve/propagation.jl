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

function propagate_local_and_global_bounds!(reform::Reformulation, presolve_form_repr::DwPresolveReform)
    master = getmaster(reform)
    presolve_restr_master = presolve_form_repr.restricted_master
    presolve_repr_master = presolve_form_repr.original_master
    for (spid, spform) in get_dw_pricing_sps(reform)
        presolve_sp = presolve_form_repr.dw_sps[spid]
        propagate_local_bounds!(presolve_sp, presolve_restr_master, spform, master)
        propagate_global_bounds!(presolve_repr_master, master, presolve_sp, spform)
        propagate_local_bounds!(presolve_sp, presolve_repr_master, spform, master)
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
            lb = presolve_sp.form.lbs[i]
            ub = presolve_sp.form.ubs[i]
            presolve_repr_master.form.lbs[repr_col] = lb * (lb < 0 ? um : lm)
            presolve_repr_master.form.ubs[repr_col] = ub * (ub < 0 ? lm : um)
        end
    end
    return
end

function propagate_local_bounds!(presolve_sp::PresolveFormulation, presolve_master::PresolveFormulation, spform::Formulation, master::Formulation)
    partial_solution = zeros(Float64, presolve_sp.form.nb_vars)
    
    # Get new columns in partial solution.
    pool = get_primal_sol_pool(spform)

    # Get new columns in partial solution.
    nb_fixed_columns = 0
    new_column_explored = true
    for (col, partial_sol_value) in enumerate(presolve_master.form.partial_solution)
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

    new_lbs = zeros(Float64, presolve_sp.form.nb_vars)
    new_ubs = zeros(Float64, presolve_sp.form.nb_vars)

    # when there is a partial solution, we update the bound so that the lower bound
    # on the absolute value of the variable is improved.
    # Examples:
    # -3 <= x <= 3  &  x = 2    ->    2 <= x <= 3
    # -3 <= x <= 3  &  x = -1   ->   -3 <= x <= -1
    #  2 <= x <= 4  &  x = 3    ->    3 <= x <= 4
    # -5 <= x <= 0  &  x = -2   ->   -5 <= x <= -2
    for (col, (val, lb, ub)) in enumerate(Iterators.zip(partial_solution, presolve_sp.form.lbs, presolve_sp.form.ubs))
        if val < 0
            new_lbs[col] = lb - val
            new_ubs[col] = min(0, ub - val)
        elseif val > 0
            new_lbs[col] = max(0, lb - val)
            new_ubs[col] = ub - val
        else
            new_lbs[col] = lb
            new_ubs[col] = ub
        end

        if lb > ub
            error("Infeasible.")
        end
    end

    presolve_sp.form.lbs = new_lbs
    presolve_sp.form.ubs = new_ubs

    lm = presolve_sp.form.lower_multiplicity
    um = presolve_sp.form.upper_multiplicity

    presolve_sp.form.lower_multiplicity = max(0, lm - nb_fixed_columns)
    presolve_sp.form.upper_multiplicity = max(0, um - nb_fixed_columns) # TODO if < 0 -> error
    return
end

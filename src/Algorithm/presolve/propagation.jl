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
        dest.form.lbs[dest_col] = src.form.lbs[src_col]
        dest.form.ubs[dest_col] = src.form.ubs[src_col]
    end

    # Look at fixed variable
    common_var_ids = intersect(keys(src.fixed_vars), keys(dest.var_to_col))

    for var_id in common_var_ids
        src_var_val = src.fixed_vars[var_id]
        dest_col = dest.var_to_col[var_id]
        dest.form.lbs[dest_col] = src_var_val
        dest.form.ubs[dest_col] = src_var_val
    end
    return
end

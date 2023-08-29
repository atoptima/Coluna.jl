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
function propagation_of_var_bounds!(reform::DwPresolveReform)
    # Original -> Representatives Master

    # Original -> Subproblem

    # Master -> Representatives Master -> Subproblem

    # Subproblem -> Representatives Master -> Master (TODO later)

    return
end

# Variable fixing propagates the same way as variable bounds.
function propagation_of_var_fixing!(reform::DwPresolveReform)
    # Original -> Representatives Master

    # Original -> Subproblem

    # Master -> Representatives Master -> Subproblem

    # Subproblem -> Representatives Master -> Master (TODO later)
    
    return
end

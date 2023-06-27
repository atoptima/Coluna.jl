"""
Returns an instance of a data structure that contain information about the stabilization
used in the column generation algorithm.
"""
@mustimplement "ColGenStab" setup_stabilization!(ctx, master) = nothing

"""
    update_stabilization_after_master_optim!(stab, phase, mast_dual_sol) -> Bool

Update stabilization after master optimization where `mast_dual_sol` is the dual solution
to the master problem.
Returns `true` if the stabilization will change the dual solution used for the pricing in the current 
column generation iteration, `false` otherwise.
"""
@mustimplement "ColGenStab" update_stabilization_after_master_optim!(stab, phase, mast_dual_sol) = nothing

"""
Returns the dual solution used for the pricing in the current column generation iteration
(stabilized dual solution).
"""
@mustimplement "ColGenStab" get_stab_dual_sol(stab, phase, mast_dual_sol) = nothing

"Returns `true` if the stabilized dual solution leads to a misprice, `false` otherwise."
@mustimplement "ColGenStab" check_misprice(stab, generated_cols, mast_dual_sol) = nothing

"""
Updates stabilization after pricing optimization where:
- `mast_dual_sol` is the dual solution to the master problem
- `valid_db` is the valid dual bound of the problem after optimization of the pricing problems
- `pseudo_db` is the pseudo dual bound of the problem after optimization of the pricing problems
- `mast_dual_sol` is the dual solution to the master problem
"""
@mustimplement "ColGenStab" update_stabilization_after_pricing_optim!(stab, ctx, generated_columns, master, valid_db, pseudo_db, mast_dual_sol) = nothing

"""
Updates stabilization after a misprice.
Argument `mast_dual_sol` is the dual solution to the master problem.
"""
@mustimplement "ColGenStab" update_stabilization_after_misprice!(stab, mast_dual_sol) = nothing

"""
Updates stabilization after an iteration of the column generation algorithm. Arguments:
- `stab` is the stabilization data structure
- `ctx` is the column generation context
- `master` is the master problem
- `generated_columns` is the set of generated columns
- `mast_dual_sol` is the dual solution to the master problem
"""
@mustimplement "ColGenStab" update_stabilization_after_iter!(stab, mast_dual_sol) = nothing

"Returns a string with a short information about the stabilization."
@mustimplement "ColGenStab" get_output_str(stab) = nothing
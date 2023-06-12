@mustimplement "ColGenStab" setup_stabilization!(ctx, master) = nothing

@mustimplement "ColGenStab" update_stabilization_after_master_optim!(stab, phase, mast_dual_sol) = nothing

@mustimplement "ColGenStab" check_misprice(stab, generated_cols, mast_dual_sol) = nothing

@mustimplement "ColGenStab" update_stabilization_after_pricing_optim!(stab, master, valid_db, pseudo_db, mast_dual_sol) = nothing

@mustimplement "ColGenStab" update_stabilization_after_misprice!(stab, mast_dual_sol) = nothing

@mustimplement "ColGenStab" update_stabilization_after_iter!(stab, master, generated_columns) = nothing
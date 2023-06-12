@mustimplement "ColGenStab" setup_stabilization!(ctx) = nothing

@mustimplement "ColGenStab" update_stabilization_after_master_optim!(stab, phase, mast_dual_sol) = nothing

@mustimplement "ColGenStab" check_misprice(stab, generated_cols, mast_dual_sol) = nothing

@mustimplement "ColGenStab" update_stabilization_after_pricing_optim!(stab, valid_db, pseudo_db, pricing_dual_sol) = nothing

@mustimplement "ColGenStab" update_stabilization_after_iter!(stab, psuedo_db) = nothing
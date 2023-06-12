struct ColGenStab{F}
    smooth_factor::Float64 # smoothing factor
    base_α::Float64 # "global" α parameter
    cur_α::Float64 # α parameter during the current misprice sequence
    nb_misprices::Int # number of misprices during the current misprice sequence
    pseudo_dual_bound::MathProg.DualBound{F} # pseudo dual bound, may be non-valid, f.e. when the pricing problem solved heuristically
    valid_dual_bound::MathProg.DualBound{F} # valid dual bound
    stab_center::Union{Nothing,MathProg.DualSolution{F}} # stability center, corresponding to valid_dual_bound
    cur_stab_center::Union{Nothing,MathProg.DualSolution{F}} # current stability center, correspond to cur_dual_bound
    stab_center_for_next_iteration::Union{Nothing,MathProg.DualSolution{F}} # to keep temporarily stab. center after update

    ColGenStab(master::F) = new{F}(
        0.5, 0.0, 0, MathProg.DualBound(master), MathProg.DualBound(master), nothing, nothing, nothing
    )
end

ColGen.setup_stabilization(ctx, master) = ColGenStab(master)


function ColGen.update_stabilization_after_master_optim!(stab::ColGenStab, phase, mast_dual_sol)
    stab.nb_misprices = 0
    stab.cur_α = 0.0

    if isnothing(stab.cur_stab_center)
        stab.cur_stab_center = mast_dual_sol
        return mast_dual_sol
    end

    # This initialisation is not very clear.
    # What's the utility of base_α if smooth factor != 1?
    stab.cur_α = stab.smooth_factor === 1.0 ? stab.base_α : stab.smooth_factor
    return stab.cur_α * stab.cur_stab_center + (1 - stab.cur_α) * mast_dual_sol 
end

function _compute_alpha(
    stab::ColGenStab, nb_new_col::Int64,  
    smooth_dual_sol, h, subgradient_contribution
) where {M}    
    # first we calculate the in-sep direction
    in_sep_direction = smooth_dual_sol - stab.cur_stab_center
    in_sep_dir_norm = norm(in_sep_direction)

    subgradient = h.a - h.A * subgradient_contribution
    subgradient_norm = norm(subgradient)

    # we now calculate the angle between the in-sep direction and the subgradient 
    angle = (transpose(in_sep_direction) * subgradient) / (in_sep_dir_norm * subgradient_norm)
    if getobjsense(master) == MaxSense
        angle *= -1
    end

    α = stab.base_α
    # we modify the alpha parameter based on the calculated angle
    if nb_new_col == 0 || angle > 1e-12 
        α = max(0.0, α - 0.1)
    elseif angle < -1e-12 && α < 0.999
        α += (1.0 - α) * 0.1
    end   
    return α
end

function ColGen.update_stabilization_after_pricing_optim!(stab::ColGenStab, valid_db, pseudo_db, pricing_dual_sol)
    if isbetter(valid_db, stab.valid_dual_bound)
        stab.cur_stab_center = pricing_dual_sol
        stab.valid_dual_bound = valid_db
    end
    if isbetter(pseudo_db, stab.pseudo_dual_bound)
        stab.stab_center_for_next_iteration = pricing_dual_sol
        stab.pseudo_dual_bound = pseudo_db
    end

    if stab.smooth_factor == 1 && stab.nb_misprices == 0
        α = _compute_alpha(stab, 0, pricing_dual_sol, h, subgradient_contribution)
        stab.base_α = α
    end
    return
end

ColGen.check_misprice(stab::ColGenStab, generated_cols, mast_dual_sol) = generated_cols <= 0

function ColGen.update_stabilization_after_misprice!(stab::ColGenStab, mast_dual_sol)
    if stab.smooth_factor < 0
        stab.cur_α = 1.0 - (stab.nb_misprices + 1) * (1 - stab.smooth_factor)
    else
        stab.cur_α = 1.0 - (1.0 - stab.cur_α) * 2
    end
    stab.nb_misprices += 1

    if stab.nb_misprices > 10 || stab.cur_α <= 0.0
        # Deactivate stabilization
        stab.cur_α = 0.0
    end
    return stab.cur_α * stab.cur_stab_center + (1 - stab.cur_α) * mast_dual_sol
end

function ColGen.update_stabilization_after_iter(stab::ColGenStab, pseudo_db)
    if !isnothing(stab.stab_center_for_next_iteration)
        stab.cur_stab_center = stab.stab_center_for_next_iteration
        stab.stab_center_for_next_iteration = nothing
    end
    return
end
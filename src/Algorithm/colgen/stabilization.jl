# struct NoColGenStab end
# ColGen.setup_stabilization(ctx, master) = NoColGenStab()
# ColGen.update_stabilization_after_master_optim!(::NoColGenStab, phase, mast_dual_sol) = nothing
# ColGen.check_misprice(::NoColGenStab, generated_cols, mast_dual_sol) = false
# ColGen.update_stabilization_after_pricing_optim!(::NoColGenStab, valid_db, pseudo_db, pricing_dual_sol) = nothing
# ColGen.update_stabilization_after_iter!(::NoColGenStab) = nothing


"""
- in: stability center
    - dual solution of the previous iteration under Neame rule, 
    - incumbent dual solution under Wentges rule.
- out: current dual solution
- sep: smoothed dual solution
    π^sep <- α * π^in + (1 - α) * π^out
"""
mutable struct ColGenStab{F}
    smooth_factor::Float64 # smoothing factor
    base_α::Float64 # "global" α parameter
    cur_α::Float64 # α parameter during the current misprice sequence
    nb_misprices::Int # number of misprices during the current misprice sequence
    pseudo_dual_bound::ColunaBase.Bound # pseudo dual bound, may be non-valid, f.e. when the pricing problem solved heuristically
    valid_dual_bound::ColunaBase.Bound # valid dual bound
    stab_center::Union{Nothing,MathProg.DualSolution{F}} # stability center, corresponding to valid_dual_bound (in point)
    cur_stab_center::Union{Nothing,MathProg.DualSolution{F}} # current stability center, correspond to cur_dual_bound
    stab_center_for_next_iteration::Union{Nothing,MathProg.DualSolution{F}} # to keep temporarily stab. center after update

    ColGenStab(master::F) where {F} = new{F}(
        0.5, 0.0, 0.0, 0, MathProg.DualBound(master), MathProg.DualBound(master), nothing, nothing, nothing
    )
end

ColGen.setup_stabilization!(ctx, master) = ColGenStab(master)


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

function ColGen.update_stabilization_after_pricing_optim!(stab::ColGenStab, master, valid_db, pseudo_db, mast_dual_sol)
    if isbetter(DualBound(master, valid_db), stab.valid_dual_bound)
        stab.cur_stab_center = mast_dual_sol
        stab.valid_dual_bound = DualBound(master, valid_db)
    end
    if isbetter(DualBound(master, pseudo_db), stab.pseudo_dual_bound)
        stab.stab_center_for_next_iteration = mast_dual_sol
        stab.pseudo_dual_bound = DualBound(master, pseudo_db)
    end
    return
end

ColGen.check_misprice(::ColGenStab, generated_cols, mast_dual_sol) = length(generated_cols.columns) == 0

function _misprice_schedule(smooth_factor, nb_misprices, cur_α)
    α = 0
    if smooth_factor < 0
        α = 1.0 - (nb_misprices) * (1 - smooth_factor)
    else
        α = 1.0 - (1.0 - cur_α) * 2
    end

    if nb_misprices > 10 || α <= 0.0
        # After 10 mis-priced iterations, we deactivate stabilization to use the "real"
        # dual solution.
        α = 0.0
    end
    return α
end

function ColGen.update_stabilization_after_misprice!(stab::ColGenStab, mast_dual_sol)
    stab.nb_misprices += 1
    α = _misprice_schedule(stab.smooth_factor, stab.nb_misprices, stab.cur_α)
    stab.cur_α = α
    return α * stab.cur_stab_center + (1 - α) * mast_dual_sol
end

f_decr(α) = max(0.0, α - 0.1)
f_incr(α) = min((1.0 - α) * 0.1, 0.9999)



function _pure_master_vars(master)
    puremastervars = Vector{Pair{VarId,Float64}}()
    for (varid, var) in getvars(master)
        if isanOriginalRepresentatives(getduty(varid)) &&
            iscuractive(master, var) && isexplicit(master, var)
            push!(puremastervars, varid => 0.0)
        end
    end
    return puremastervars
end


function _primal_solution(master::Formulation, generated_columns, is_minimization)
    sense = MathProg.getobjsense(master)
    var_ids = MathProg.VarId[]
    var_vals = Float64[]

    puremastervars = _pure_master_vars(master)
    for (var_id, mult) in puremastervars
        push!(var_ids, var_id)
        push!(var_vals, mult) # always 0 in the previous implementation ?
    end

    for col in generated_columns
        @show col
    end

    # for (_, spinfo) in spinfos
    #     iszero(spinfo.ub) && continue


    #     mult = improving_red_cost(getbound(spinfo.bestsol), algo, sense) ? spinfo.ub : spinfo.lb
    #     for (sp_var_id, sp_var_val) in spinfo.bestsol
    #         push!(var_ids, sp_var_id)
    #         push!(var_vals, sp_var_val * mult)
    #     end
    # end
    # return sparsevec(var_ids, var_vals)
end


function _dynamic_alpha_schedule(
    stab::ColGenStab, smooth_dual_sol, h, primal_solution, is_minimization
) where {M}    
    # Calculate the in-sep direction.
    in_sep_direction = smooth_dual_sol - stab.cur_stab_center
    in_sep_dir_norm = norm(in_sep_direction)

    # Calculate the subgradient
    subgradient = h.a - h.A * primal_solution
    subgradient_norm = norm(subgradient)

    # we now calculate the angle between the in-sep direction and the subgradient 
    angle = (transpose(in_sep_direction) * subgradient) / (in_sep_dir_norm * subgradient_norm)
    if !is_minimization
        angle *= -1
    end

    # we modify the alpha parameter based on the calculated angle
    α = angle > 1e-12 ? f_decr(stab.base_α) : f_incr(stab.base_α)
    return α
end

function ColGen.update_stabilization_after_iter!(stab::ColGenStab, master, generated_columns)
    if stab.smooth_factor == 1
        primal_sol = _primal_solution(master, generated_columns, true)
        #α = _dynamic_alpha_schedule(stab, 0, pricing_dual_sol, h, primal_sol)
        stab.base_α = 0.1 #α
    end

    if !isnothing(stab.stab_center_for_next_iteration)
        stab.cur_stab_center = stab.stab_center_for_next_iteration
        stab.stab_center_for_next_iteration = nothing
    end
    return
end
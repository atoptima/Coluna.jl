struct NoColGenStab end
#ColGen.setup_stabilization(ctx, master) = NoColGenStab()
ColGen.update_stabilization_after_master_optim!(::NoColGenStab, phase, mast_dual_sol) = false
ColGen.get_stab_dual_sol(::NoColGenStab, phase, mast_dual_sol) = mast_dual_sol
ColGen.check_misprice(::NoColGenStab, generated_cols, mast_dual_sol) = false
ColGen.update_stabilization_after_misprice!(::NoColGenStab, mast_dual_sol) = nothing
ColGen.update_stabilization_after_iter!(::NoColGenStab, mast_dual_sol) = nothing
ColGen.get_output_str(::NoColGenStab) = 0.0
"""
Implementation of the "Smoothing with a self adjusting parameter" described in the paper of
Pessoa et al.

TODO: docstring

- in: stability center
    - dual solution of the previous iteration under Neame rule, 
    - incumbent dual solution under Wentges rule.
- out: current dual solution
- sep: smoothed dual solution
    π^sep <- α * π^in + (1 - α) * π^out
"""
mutable struct ColGenStab{F}
    automatic::Bool
    base_α::Float64 # "global" α parameter
    cur_α::Float64 # α parameter during the current misprice sequence
    nb_misprices::Int # number of misprices during the current misprice sequence
    pseudo_dual_bound::ColunaBase.Bound # pseudo dual bound, may be non-valid, f.e. when the pricing problem solved heuristically
    valid_dual_bound::ColunaBase.Bound # valid dual bound
    stab_center::Union{Nothing,MathProg.DualSolution{F}} # stability center, corresponding to valid_dual_bound (in point)
    cur_stab_center::Union{Nothing,MathProg.DualSolution{F}} # current stability center, correspond to cur_dual_bound
    stab_center_for_next_iteration::Union{Nothing,MathProg.DualSolution{F}} # to keep temporarily stab. center after update

    ColGenStab(master::F, automatic, init_α) where {F} = new{F}(
        automatic, init_α, 0.0, 0, MathProg.DualBound(master), MathProg.DualBound(master), nothing, nothing, nothing
    )
end

ColGen.get_output_str(stab::ColGenStab) = stab.base_α

function ColGen.update_stabilization_after_master_optim!(stab::ColGenStab, phase, mast_dual_sol)
    stab.nb_misprices = 0
    stab.cur_α = 0.0

    if isnothing(stab.cur_stab_center)
        stab.cur_stab_center = mast_dual_sol
        return false
    end

    stab.cur_α = stab.base_α
    return stab.cur_α > 0
end

function ColGen.get_stab_dual_sol(stab::ColGenStab, phase, mast_dual_sol)
    return stab.cur_α * stab.cur_stab_center + (1 - stab.cur_α) * mast_dual_sol
end

ColGen.check_misprice(stab::ColGenStab, generated_cols, mast_dual_sol) = length(generated_cols.columns) == 0 && stab.cur_α > 0.0

function _misprice_schedule(automatic, nb_misprices, base_α)
    # Rule from the paper Pessoa et al. (α-schedule in a mis-pricing sequence, Step 1)
    α = 1.0 - (nb_misprices + 1) * (1 - base_α)

    if nb_misprices > 10 || α <= 1e-3
        # After 10 mis-priced iterations, we deactivate stabilization to use the "real"
        # dual solution.
        α = 0.0
    end
    return α
end

function ColGen.update_stabilization_after_misprice!(stab::ColGenStab, mast_dual_sol)
    stab.nb_misprices += 1
    α = _misprice_schedule(stab.automatic, stab.nb_misprices, stab.base_α)
    stab.cur_α = α
    return
end

f_decr(α) = max(0.0, α - 0.1)
f_incr(α) = min(α + (1.0 - α) * 0.1, 0.9999)

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

    for (sp_id, sp_primal_sol) in generated_columns.subprob_primal_sols.primal_sols
        sp = getmodel(sp_primal_sol)
        lb = getcurrhs(master, sp.duty_data.lower_multiplicity_constr_id)
        ub = getcurrhs(master, sp.duty_data.upper_multiplicity_constr_id)
        iszero(ub) && continue
        mult = get(generated_columns.subprob_primal_sols.improve_master, sp_id, false) ? ub : lb
        for (sp_var_id, sp_var_val) in sp_primal_sol
            push!(var_ids, sp_var_id)
            push!(var_vals, sp_var_val * mult)
        end
    end
    return sparsevec(var_ids, var_vals)
end

function _increase(smooth_dual_sol, cur_stab_center, h, primal_solution, is_minimization)
    # Calculate the in-sep direction.
    in_sep_direction = smooth_dual_sol - cur_stab_center
    in_sep_dir_norm = norm(in_sep_direction)

    # if in & sep are the same point, we need to decrease α becase it is the weight of the
    # stability center (in) in the formula to compute the sep point.
    if iszero(in_sep_dir_norm)
        return false
    end

    # Calculate the subgradient
    subgradient = h.a - h.A * primal_solution
    subgradient_norm = norm(subgradient)

    # we now calculate the angle between the in-sep direction and the subgradient 
    cos_angle = (transpose(in_sep_direction) * subgradient) / (in_sep_dir_norm * subgradient_norm)

    if !is_minimization
        cos_angle *= -1
    end
    return cos_angle < 1e-12
end

function _dynamic_alpha_schedule(
    α, smooth_dual_sol, cur_stab_center, h, primal_solution, is_minimization
)
    increase = _increase(smooth_dual_sol, cur_stab_center, h, primal_solution, is_minimization)
    # we modify the alpha parameter based on the calculated angle
    return increase ? f_incr(α) : f_decr(α)
end

function ColGen.update_stabilization_after_iter!(stab::ColGenStab, mast_dual_sol)
    if !isnothing(stab.stab_center_for_next_iteration)
        stab.cur_stab_center = stab.stab_center_for_next_iteration
        stab.stab_center_for_next_iteration = nothing
    end
    return
end
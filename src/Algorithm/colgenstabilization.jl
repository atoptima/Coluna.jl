mutable struct ColGenStabilizationRecord <: AbstractRecord
    basealpha::Float64 # "global" alpha parameter
    curalpha::Float64 # alpha parameter during the current misprice sequence
    nb_misprices::Int64 # number of misprices during the current misprice sequence
    pseudo_dual_bound::DualBound # pseudo dual bound, may be non-valid, f.e. when the pricing problem solved heuristically
    valid_dual_bound::DualBound # valid dual bound
    stabcenter::Union{Nothing,DualSolution} # current stability center, correspond to cur_dual_bound
    newstabcenter::Union{Nothing,DualSolution} # to keep temporarily stab. center after update
    basestabcenter::Union{Nothing,DualSolution} # stability center, corresponding to valid_dual_bound
end

function ColGenStabilizationRecord(master::Formulation)
    return ColGenStabilizationRecord(
        0.5, 0.0, 0, DualBound(master), DualBound(master), nothing, nothing, nothing
    )
end

smoothing_is_active(record::ColGenStabilizationRecord) = !iszero(record.curalpha)

subgradient_is_needed(record::ColGenStabilizationRecord, smoothparam::Float64) =
    smoothparam == 1.0 && record.nb_misprices == 0

mutable struct ColGenStabRecordState <: AbstractRecordState
    alpha::Float64
    dualbound::DualBound
    stabcenter::Union{Nothing,DualSolution}
end

function ColGenStabRecordState(master::Formulation, record::ColGenStabilizationRecord)
    alpha = record.basealpha < 0.5 ? 0.5 : record.basealpha
    return ColGenStabRecordState(alpha, record.valid_dual_bound, record.basestabcenter)
end

function restorefromstate!(
    master::Formulation, record::ColGenStabilizationRecord, state::ColGenStabRecordState
)
    record.basealpha = state.alpha
    record.valid_dual_bound = state.dualbound
    record.basestabcenter = state.stabcenter
    return
end

const ColGenStabilizationRecordPair = (ColGenStabilizationRecord => ColGenStabRecordState)

function init_stab_before_colgen_loop!(record::ColGenStabilizationRecord)
    record.stabcenter = record.basestabcenter
    record.pseudo_dual_bound = record.valid_dual_bound
    return
end

function componentwisefunction(in_dual_sol::DualSolution, out_dual_sol::DualSolution, f::Function)
    form = out_dual_sol.model
    constrids = Vector{ConstrId}()
    constrvals = Vector{Float64}()
    value::Float64 = 0.0
    out_next = iterate(out_dual_sol)
    in_next = iterate(in_dual_sol)
    while out_next !== nothing || in_next !== nothing
        if out_next !== nothing 
            ((out_constrid, out_val), out_state) = out_next
            if in_next !== nothing
                ((in_constrid, in_val), in_state) = in_next
                if in_constrid < out_constrid
                    value = f(in_val, 0.0)
                    push!(constrids, in_constrid)
                    push!(constrvals, value)
                    in_next = iterate(in_dual_sol, in_state)
                elseif out_constrid < in_constrid    
                    value = f(0.0, out_val)
                    push!(constrids, out_constrid)
                    push!(constrvals, value)
                    out_next = iterate(out_dual_sol, out_state)    
                else
                    push!(constrids, out_constrid)
                    value = f(in_val, out_val)
                    push!(constrvals, value)
                    in_next = iterate(in_dual_sol, in_state)
                    out_next = iterate(out_dual_sol, out_state)    
                end
            else
                value = f(0.0, out_val)
                push!(constrids, out_constrid)
                push!(constrvals, value)
                out_next = iterate(out_dual_sol, out_state)    
            end
        else    
            ((in_constrid, in_val), in_state) = in_next
            value = f(in_val, 0.0)
            push!(constrids, in_constrid)
            push!(constrvals, value)
            in_next = iterate(in_dual_sol, in_state)
        end
    end
    return (constrids, constrvals)
end

function linear_combination(in_dual_sol::DualSolution, out_dual_sol::DualSolution, coeff::Float64)
    constrids, constrvals = componentwisefunction(
        in_dual_sol, out_dual_sol, 
        (x, y) -> coeff * x + (1.0 - coeff) * y
    )

    form = in_dual_sol.model
    bound = 0.0
    for (i, constrid) in enumerate(constrids)
        bound += constrvals[i] * getcurrhs(form, constrid) 
    end
    return DualSolution(form, constrids, constrvals, bound, UNKNOWN_FEASIBILITY)
end

function update_stab_after_rm_solve!(
    record::ColGenStabilizationRecord, smoothparam::Float64, lp_dual_sol::DualSolution
)
    iszero(smoothparam) && return lp_dual_sol

    record.curalpha = 0.0
    record.nb_misprices = 0

    if record.stabcenter === nothing
        # cannot do smoothing, just return the current dual solution
        record.stabcenter = lp_dual_sol
        return lp_dual_sol
    end

    record.curalpha = smoothparam == 1.0 ? record.basealpha : smoothparam

    return linear_combination(record.stabcenter, lp_dual_sol, record.curalpha)
    end

function norm(dualsol::DualSolution)
    product_sum = 0.0
    for (constrid, val) in dualsol
        product_sum += val * val
    end
    return sqrt(product_sum)
end

function update_alpha_automatically!(
    record::ColGenStabilizationRecord, nb_new_col::Int64, lp_dual_sol::DualSolution{M},  
    smooth_dual_sol::DualSolution{M}, subgradient_contribution::DualSolution{M}
) where {M}    

    master = lp_dual_sol.model 

    # first we calculate the in-sep direction
    constrids, constrvals = componentwisefunction(smooth_dual_sol, record.stabcenter, -)
    in_sep_direction = DualSolution(master, constrids, constrvals, 0.0, UNKNOWN_FEASIBILITY)
    in_sep_dir_norm = norm(in_sep_direction)

    # we initialize the subgradient with the right-hand-side of all master constraints
    # except the convexity constraints
    constrids = Vector{ConstrId}()
    constrrhs = Vector{Float64}() 
    for (constrid, constr) in getconstrs(master)
        if !(getduty(constrid) <= MasterConvexityConstr) && 
           iscuractive(master, constr) && isexplicit(master, constr)
            push!(constrids, constrid)
            push!(constrrhs, getcurrhs(master, constrid))
        end 
    end
    subgradient = DualSolution(master, constrids, constrrhs, 0.0, UNKNOWN_FEASIBILITY)
    
    # we calculate the subgradient at the sep point
    for (constrid, value) in subgradient_contribution
        subgradient[constrid] = subgradient[constrid] - value
    end
    subgradient_norm = norm(subgradient)

    # we now calculate the angle between the in-sep direction and the subgradient 
    constrids, constrvals = componentwisefunction(in_sep_direction, subgradient, *)
    angle = sum(constrvals) / (in_sep_dir_norm * subgradient_norm)
    if getobjsense(master) == MaxSense
        angle = -angle
    end

    # we modify the alpha parameter based on the calculated angle
    if nb_new_col == 0 || angle > 1e-12 
        record.basealpha -= 0.1
    elseif angle < -1e-12 && record.basealpha < 0.999
        record.basealpha += (1.0 - record.basealpha) * 0.1
    end   
    return 
end

function update_stab_after_gencols!(
    record::ColGenStabilizationRecord, smoothparam::Float64, nb_new_col::Int64, 
    lp_dual_sol::DualSolution{M}, smooth_dual_sol::DualSolution{M}, 
    subgradient_contribution::DualSolution{M}
) where {M}

    iszero(smoothparam) && return nothing

    if smoothparam == 1.0 && record.nb_misprices == 0
        update_alpha_automatically!(
            record, nb_new_col, lp_dual_sol, smooth_dual_sol, subgradient_contribution
        )
    end

    if nb_new_col > 0 || !smoothing_is_active(record)
        return nothing
    end

    if smoothparam < 0
        record.curalpha = 1.0 - (record.nb_misprices + 1) * (1 - smoothparam)
    else
        record.curalpha = 1.0 - (1.0 - record.curalpha) * 2
    end

    record.nb_misprices += 1

    if record.nb_misprices > 10 || record.curalpha <= 0.0
        record.curalpha = 0.0
        return lp_dual_sol
    end

    return linear_combination(record.stabcenter, lp_dual_sol, record.curalpha)
end

function update_stability_center!(
    record::ColGenStabilizationRecord, dual_sol::DualSolution, 
    valid_lagr_bound::DualBound, pseudo_lagr_bound::DualBound 
)
    if isbetter(valid_lagr_bound, record.valid_dual_bound)
        record.basestabcenter = dual_sol
        record.valid_dual_bound = valid_lagr_bound
    end
    if isbetter(pseudo_lagr_bound, record.pseudo_dual_bound)
        record.newstabcenter = dual_sol
        record.pseudo_dual_bound = pseudo_lagr_bound
    end
    return
end

function update_stab_after_colgen_iteration!(record::ColGenStabilizationRecord)
    if record.newstabcenter !== nothing
        record.stabcenter = record.newstabcenter
    end
    record.curalpha = 0.0 
    record.newstabcenter = nothing
    return
end

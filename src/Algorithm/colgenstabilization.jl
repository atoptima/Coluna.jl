mutable struct ColGenStabilizationUnit <: AbstractNewStorageUnit
    basealpha::Float64 # "global" alpha parameter
    curalpha::Float64 # alpha parameter during the current misprice sequence
    nb_misprices::Int64 # number of misprices during the current misprice sequence
    pseudo_dual_bound::DualBound # pseudo dual bound, may be non-valid, f.e. when the pricing problem solved heuristically
    valid_dual_bound::DualBound # valid dual bound
    stabcenter::Union{Nothing,DualSolution} # current stability center, correspond to cur_dual_bound
    newstabcenter::Union{Nothing,DualSolution} # to keep temporarily stab. center after update
    basestabcenter::Union{Nothing,DualSolution} # stability center, corresponding to valid_dual_bound
end

function ClB.new_storage_unit(::Type{ColGenStabilizationUnit}, master::Formulation{DwMaster})
    return ColGenStabilizationUnit(
        0.5, 0.0, 0, DualBound(master), DualBound(master), nothing, nothing, nothing
    )
end

mutable struct ColGenStabRecord <: AbstractNewRecord
    alpha::Float64
    dualbound::DualBound
    stabcenter::Union{Nothing,DualSolution}
end

struct ColGenStabKey <: AbstractStorageUnitKey end

key_from_storage_unit_type(::Type{ColGenStabilizationUnit}) = ColGenStabKey()
record_type_from_key(::ColGenStabKey) = ColGenStabRecord

function ClB.new_record(::Type{ColGenStabRecord}, id::Int, form::Formulation, unit::ColGenStabilizationUnit)
    alpha = unit.basealpha < 0.5 ? 0.5 : unit.basealpha
    return ColGenStabRecord(alpha, unit.valid_dual_bound, unit.basestabcenter)
end

ClB.record_type(::Type{ColGenStabilizationUnit}) = ColGenStabRecord
ClB.storage_unit_type(::Type{ColGenStabRecord}) = ColGenStabilizationUnit



function ClB.restore_from_record!(
    ::Formulation, unit::ColGenStabilizationUnit, state::ColGenStabRecord
)
    unit.basealpha = state.alpha
    unit.valid_dual_bound = state.dualbound
    unit.basestabcenter = state.stabcenter
    return
end


# function ColGenStabilizationUnit(master::Formulation)
#     return ColGenStabilizationUnit(
#         0.5, 0.0, 0, DualBound(master), DualBound(master), nothing, nothing, nothing
#     )
# end

# function ColGenStabRecord(master::Formulation, unit::ColGenStabilizationUnit)
#     alpha = unit.basealpha < 0.5 ? 0.5 : unit.basealpha
#     return ColGenStabRecord(alpha, unit.valid_dual_bound, unit.basestabcenter)
# end

smoothing_is_active(unit::ColGenStabilizationUnit) = !iszero(unit.curalpha)

subgradient_is_needed(unit::ColGenStabilizationUnit, smoothparam::Float64) =
    smoothparam == 1.0 && unit.nb_misprices == 0



function init_stab_before_colgen_loop!(unit::ColGenStabilizationUnit)
    unit.stabcenter = unit.basestabcenter
    unit.pseudo_dual_bound = unit.valid_dual_bound
    return
end

function update_stab_after_rm_solve!(
    unit::ColGenStabilizationUnit, smoothparam::Float64, lp_dual_sol::DualSolution
)
    iszero(smoothparam) && return lp_dual_sol

    unit.curalpha = 0.0
    unit.nb_misprices = 0

    if unit.stabcenter === nothing
        # cannot do smoothing, just return the current dual solution
        unit.stabcenter = lp_dual_sol
        return lp_dual_sol
    end

    unit.curalpha = smoothparam == 1.0 ? unit.basealpha : smoothparam

    if !smoothing_is_active(unit)
        # in this case Lagrangian bound calculation is simplified in col.gen.
        # (we use the fact that the contribution of pure master variables 
        #  is included in the value of the LP dual solution)
        # thus, LP dual solution should be retured, as linear combination
        # does not include pure master variables contribution to the bound
        return lp_dual_sol
    end
    return unit.curalpha * unit.stabcenter + (1.0 - unit.curalpha) * lp_dual_sol
end

function update_alpha_automatically!(
    unit::ColGenStabilizationUnit, nb_new_col::Int64, lp_dual_sol::DualSolution{M},  
    smooth_dual_sol::DualSolution{M}, h, subgradient_contribution
) where {M}    

    master = getmodel(lp_dual_sol)

    # first we calculate the in-sep direction
    in_sep_direction = smooth_dual_sol - unit.stabcenter
    in_sep_dir_norm = norm(in_sep_direction)

    subgradient = h.a - h.A * subgradient_contribution
    subgradient_norm = norm(subgradient)

    # we now calculate the angle between the in-sep direction and the subgradient 
    angle = (transpose(in_sep_direction) * subgradient) / (in_sep_dir_norm * subgradient_norm)
    if getobjsense(master) == MaxSense
        angle *= -1
    end

    # we modify the alpha parameter based on the calculated angle
    if nb_new_col == 0 || angle > 1e-12 
        unit.basealpha = max(0.0, unit.basealpha - 0.1)
    elseif angle < -1e-12 && unit.basealpha < 0.999
        unit.basealpha += (1.0 - unit.basealpha) * 0.1
    end   
    return 
end

function update_stab_after_gencols!(
    unit::ColGenStabilizationUnit, smoothparam::Float64, nb_new_col::Int64, 
    lp_dual_sol::DualSolution{M}, smooth_dual_sol::DualSolution{M}, h,
    subgradient_contribution
) where {M}

    iszero(smoothparam) && return nothing

    if smoothparam == 1.0 && unit.nb_misprices == 0
        update_alpha_automatically!(
            unit, nb_new_col, lp_dual_sol, smooth_dual_sol, h, subgradient_contribution
        )
    end

    if nb_new_col > 0 || !smoothing_is_active(unit)
        return nothing
    end

    if smoothparam < 0
        unit.curalpha = 1.0 - (unit.nb_misprices + 1) * (1 - smoothparam)
    else
        unit.curalpha = 1.0 - (1.0 - unit.curalpha) * 2
    end

    unit.nb_misprices += 1

    if unit.nb_misprices > 10 || unit.curalpha <= 0.0
        unit.curalpha = 0.0
        # stabilization is deactivated, thus we need to return the original LP dual solution
        return lp_dual_sol
    end
    return unit.curalpha * unit.stabcenter + (1.0 - unit.curalpha) * lp_dual_sol
end

function update_stability_center!(
    unit::ColGenStabilizationUnit, dual_sol::DualSolution, 
    valid_lagr_bound::DualBound, pseudo_lagr_bound::DualBound 
)
    if isbetter(valid_lagr_bound, unit.valid_dual_bound)
        unit.basestabcenter = dual_sol
        unit.valid_dual_bound = valid_lagr_bound
    end
    if isbetter(pseudo_lagr_bound, unit.pseudo_dual_bound)
        unit.newstabcenter = dual_sol
        unit.pseudo_dual_bound = pseudo_lagr_bound
    end
    return
end

function update_stab_after_colgen_iteration!(unit::ColGenStabilizationUnit)
    if unit.newstabcenter !== nothing
        unit.stabcenter = unit.newstabcenter
    end
    unit.curalpha = 0.0 
    unit.newstabcenter = nothing
    return
end

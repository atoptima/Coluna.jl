############# Stabilization storage and state ###########################

mutable struct ColGenStabStorage <: AbstractStorage
    basealpha::Float64
    curalpha::Float64
    nb_misprices::Int64
    stabcenter::Union{Nothing, DualSolution{Formulation}}
end

ColGenStabStorage(master::Formulation) = ColGenStabStorage(0.5, 0.0, 0, nothing)
ColGenStabStorage() = ColGenStabStorage(0.0, 0.0, 0, nothing)

smoothing_is_active(storage::ColGenStabStorage) = iszero(storage.curalpha)

mutable struct ColGenStabStorageState <: AbstractStorageState
    alpha::Float64
    stabcenter::Union{Nothing, DualSolution{Formulation}}
end

function ColGenStabStorageState(master::Formulation, storage::ColGenStabStorage)
    return ColGenStabStorageState(storage.basealpha, storage.stabcenter)
end

function restorefromstate!(
    master::Formulation, storage::ColGenStabStorage, state::ColGenStabStorageState
)
    storage.basealpha = state.alpha
    storage.stabcenter = state.stabcenter
end

const ColGenStabilizationStorage = (ColGenStabStorage => ColGenStabStorageState)

############## Stabilization functions ##########

function linear_combination(out_dual_sol::DualSolution, in_dual_sol::DualSolution, coeff::Float64)
    # TO DO 
    return out_dual_sol
end

function init_stab_after_rm_solve!(storage::ColGenStabStorage, smoothparam::Float64, lp_dual_sol::DualSolution)
    storage.curalpha = 0.0
    storage.nb_misprices = 0

    if storage.stabcenter === nothing
        # cannot do smoothing, just return the current dual solution
        return lp_dual_sol
    end

    storage.curalpha = smoothparam == 1.0 ? storage.basealpha : smoothparam

    return linear_combination(lp_dual_sol, storage.stabcenter, storage.curalpha)
end

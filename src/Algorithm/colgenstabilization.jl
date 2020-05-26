############# Stabilization storage and state ###########################

mutable struct ColGenStabStorage <: AbstractStorage
    basealpha::Float64
    curalpha::Float64
    nb_misprices::Int64
    stabcenter::Union{Nothing, DualSolution{Formulation{MathProg.DwMaster}}}
    newstabcenter::Union{Nothing, DualSolution{Formulation{MathProg.DwMaster}}}
end

ColGenStabStorage(master::Formulation) = ColGenStabStorage(0.5, 0.0, 0, nothing, nothing)
ColGenStabStorage() = ColGenStabStorage(0.0, 0.0, 0, nothing, nothing)

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
                    if !(getduty(out_constrid) <= MasterConvexityConstr)    
                        value = f(0.0, out_val)
                        push!(constrids, out_constrid)
                        push!(constrvals, value)
                    end
                    out_next = iterate(out_dual_sol, out_state)    
                else
                    push!(constrids, out_constrid)
                    value = f(in_val, out_val)
                    push!(constrvals, value)
                    in_next = iterate(in_dual_sol, in_state)
                    out_next = iterate(out_dual_sol, out_state)    
                end
            else
                if !(getduty(out_constrid) <= MasterConvexityConstr)    
                    value = f(0.0, out_val)
                    push!(constrids, out_constrid)
                    push!(constrvals, value)
                end
                out_next = iterate(out_dual_sol, out_state)    
            end
        else    
            ((in_constrid, in_val), in_state) = in_next
            value = f(in_val, 0.0)
            push!(constrids, in_constrid)
            push!(constrvals, value)
            # bound += smoothed_value * getcurrhs(form, in_constrid) 
            in_next = iterate(in_dual_sol, in_state)
        end
    end

    return (constrids, constrvals)
end

function init_stab_after_rm_solve!(storage::ColGenStabStorage, smoothparam::Float64, lp_dual_sol::DualSolution)
    storage.curalpha = 0.0
    storage.nb_misprices = 0

    if storage.stabcenter === nothing
        # cannot do smoothing, just return the current dual solution
        storage.stabcenter = lp_dual_sol
        return lp_dual_sol
    end

    storage.curalpha = smoothparam == 1.0 ? storage.basealpha : smoothparam
    storage.curalpha = 0.5

    constrids, constrvals = componentwisefunction(
        storage.stabcenter, lp_dual_sol, 
        (x, y) -> storage.curalpha * x + (1.0 - storage.curalpha) * y
    )

    form = lp_dual_sol.model
    bound = 0.0
    for (i, constrid) in enumerate(constrids)
        bound += constrvals[i] * getcurrhs(form, constrid) 
    end
    return DualSolution(form, constrids, constrvals, bound)
end

function update_alpha_automatically!(
    storage::ColGenStabStorage, lp_dual_sol::DualSolution{M}, 
    smooth_dual_sol::DualSolution{M}, best_cols_ids_and_bounds::Vector{VarId, Float64, Float64}
) where {M}    
    # first we calculate the IN-SEP direction
    constrids, constrvals = componentwisefunction(smooth_dual_sol, storage.stabcenter, -)
    in_sep_norm = 0.0
    for val in constrvals
        in_sep_norm += val * val
    end
    in_sep_norm = sqrt(in_sep_norm)

    # we initialize the subgradient with the right-hand-side of all master constraints
    # except the convexity constraints
    master = lp_dual_sol.model 
    constrids = Vector{ConstrId}()
    constrrhs = Vector{Float64}() 
    for (constrid, constr) in getconstrs(master)
        if !(getduty(constrid) <= MasterConvexityConstr) && 
           iscuractive(master, constr) && isexplicit(master, constr)
            push!(constrids, constrid)
            push!(constrrhs, getcurrhs(master, constrid))
        end 
    end
    subgradient = DualSolution(master, constrids, constrrhs, 0.0)
end

function update_stab_after_gencols!(
    storage::ColGenStabStorage, smoothparam::Float64, nb_new_col::Int64, 
    lp_dual_sol::DualSolution{M}, smooth_dual_sol::DualSolution{M}, 
    best_cols_ids_and_bounds::Vector{VarId, Float64, Float64}
) where {M}
    smoothing_is_active(storage) && return nothing

    if smoothparam == 1.0 && storage.nb_misprices == 0
        update_alpha_automatically!(storage, lp_dual_sol, smooth_dual_sol, best_cols_ids_and_bounds)
    end

    nb_new_col > 0 && return nothing

    if smoothparam < 0
        storage.curalpha = 1.0 - (storage.nb_misprices + 1) * (1 - smoothparam)
    else
        storage.curalpha = 1.0 - (1.0 - storage.curalpha) * 2
    end

    storage.nb_misprices += 1

    if storage.nb_misprices > 10 || storage.curalpha < 0.0
        storage.curalpha = 0.0
    end

    return linear_combination(lp_dual_sol, storage.stabcenter, storage.curalpha)
end

function update_stab_after_colgen_iteration!(storage::ColGenStabStorage)
    if storage.newstabcenter !== nothing
        storage.stabcenter = storage.newstabcenter
    end
    storage.curalpha = 0.0 
    storage.newstabcenter = nothing
end

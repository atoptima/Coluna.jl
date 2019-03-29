mutable struct SolsAndBounds
    alg_inc_ip_primal_bound::Float64
    alg_inc_lp_primal_bound::Float64
    alg_inc_ip_dual_bound::Float64
    alg_inc_lp_dual_bound::Float64
    alg_inc_lp_primal_sol_map::Dict{Variable, Float64}
    alg_inc_ip_primal_sol_map::Dict{Variable, Float64}
    alg_inc_lp_dual_sol_map::Dict{Constraint, Float64}
    is_alg_inc_ip_primal_bound_updated::Bool
end

SolsAndBounds() = SolsAndBounds(Inf, Inf, -Inf, -Inf, Dict{Variable, Float64}(),
        Dict{Variable, Float64}(), Dict{Constraint, Float64}(), false)

### Methods of SolsAndBounds
function update_primal_lp_bound(incumbents::SolsAndBounds, newbound::Float64)
    if newbound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newbound
    end
end

function update_primal_ip_incumbents(incumbents::SolsAndBounds,
        var_val_map::Dict{Variable,Float64}, newbound::Float64)
    if newbound < incumbents.alg_inc_ip_primal_bound
        incumbents.alg_inc_ip_primal_bound = newbound
        incumbents.alg_inc_ip_primal_sol_map = Dict{Variable, Float64}()
        for var_val in var_val_map
            push!(incumbents.alg_inc_ip_primal_sol_map, var_val)
        end
        incumbents.is_alg_inc_ip_primal_bound_updated = true
    end
end

function update_primal_lp_incumbents(incumbents::SolsAndBounds,
        var_val_map::Dict{Variable,Float64}, newbound::Float64)
    if newbound < incumbents.alg_inc_lp_primal_bound
        incumbents.alg_inc_lp_primal_bound = newbound
        incumbents.alg_inc_lp_primal_sol_map = Dict{Variable, Float64}()
        for var_val in var_val_map
            push!(incumbents.alg_inc_lp_primal_sol_map, var_val)
        end
    end
end

function update_dual_lp_bound(incumbents::SolsAndBounds, newbound::Float64)
    if newbound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newbound
    end
end

function update_dual_ip_bound(incumbents::SolsAndBounds, newbound::Float64)
    new_ip_bound = newbound
    # new_ip_bound = ceil(newbound) # TODO ceil if objective is integer
    if new_ip_bound > incumbents.alg_inc_ip_dual_bound
        incumbents.alg_inc_ip_dual_bound = new_ip_bound
    end
end

function update_dual_lp_incumbents(incumbents::SolsAndBounds,
        constr_val_map::Dict{Constraint, Float64}, newbound::Float64)
    if newbound > incumbents.alg_inc_lp_dual_bound
        incumbents.alg_inc_lp_dual_bound = newbound
        incumbents.alg_inc_lp_dual_sol_map = Dict{Constraint, Float64}()
        for constr_val in constr_val_map
            push!(incumbents.alg_inc_lp_dual_sol_map, constr_val)
        end
    end
end

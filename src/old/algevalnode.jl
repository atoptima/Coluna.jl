##########################
#### AlgToEvalNode #######
##########################

abstract type AlgLike end
abstract type AlgToEvalNode <: AlgLike end

# @hl mutable struct AlgToEvalNode <: AlgLike
#     sols_and_bounds::SolsAndBounds
#     extended_problem::Reformulation
#     sol_is_master_lp_feasible::Bool
#     is_master_converged::Bool
# end

# AlgToEvalNodeBuilder(problem::Reformulation) = (SolsAndBounds(),
#                                                   problem, false, false)

function update_alg_primal_lp_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    primal_bnd = master.primal_sol.cost
    update_primal_lp_bound(alg.sols_and_bounds, primal_bnd)
end

function update_alg_primal_lp_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    primal_sol = master.primal_sol.var_val_map
    primal_bnd = master.primal_sol.cost
    update_primal_lp_incumbents(alg.sols_and_bounds, primal_sol, primal_bnd)
end

function update_alg_primal_ip_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    primal_sol = master.primal_sol.var_val_map
    primal_bnd = master.primal_sol.cost
    if is_sol_integer(primal_sol,
                      alg.extended_problem.params.mip_tolerance_integrality)
        update_primal_ip_incumbents(alg.sols_and_bounds, primal_sol, primal_bnd)
    end
end

function update_alg_dual_lp_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_bnd = master.dual_sol.cost
    update_dual_lp_bound(alg.sols_and_bounds, dual_bnd)
end

function update_alg_dual_lp_incumbents(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_sol = master.dual_sol.constr_val_map
    dual_bnd = master.dual_sol.cost
    ## not retreiving dual solution yet, but lp dual = lp primal
    update_dual_lp_incumbents(alg.sols_and_bounds, dual_sol, dual_bnd)
end

function update_alg_dual_ip_bound(alg::AlgToEvalNode)
    master = alg.extended_problem.master_problem
    dual_bnd = master.dual_sol.cost
    update_dual_ip_bound(alg.sols_and_bounds, dual_bnd)
end

function mark_infeasible(alg::AlgToEvalNode)
    alg.sols_and_bounds.alg_inc_lp_primal_bound = Inf
    alg.sols_and_bounds.alg_inc_ip_dual_bound = Inf
    alg.sols_and_bounds.alg_inc_lp_dual_bound = Inf
    alg.sol_is_master_lp_feasible = false
end

# @hl mutable struct AlgToPrimalHeurInNode <: AlgLike
#     sols_and_bounds::SolsAndBounds
#     extended_problem::Reformulation
# end

# AlgToPrimalHeurInNodeBuilder(prob::Reformulation) = (SolsAndBounds(), prob)

# @hl mutable struct AlgToPrimalHeurByRestrictedMip <: AlgToPrimalHeurInNode
#     optimizer_type::DataType
# end

# AlgToPrimalHeurByRestrictedMipBuilder(prob::Reformulation,
#                                       solver_type::DataType) =
#         tuplejoin(AlgToPrimalHeurInNodeBuilder(prob), solver_type)

# function run(alg::AlgToPrimalHeurByRestrictedMip, global_treat_order::TreatOrder)
#     @timeit to(alg) "Restricted master IP" begin

#     @timeit to(alg) "Setup of optimizer" begin
#     master_problem = alg.extended_problem.master_problem
#     switch_primary_secondary_moi_def(master_problem)
#     mip_optimizer = alg.optimizer_type()
#     load_problem_in_optimizer(master_problem, mip_optimizer, false)
#     end
#     @timeit to(alg) "Solving" begin
#     status, primal_sol, dual_sol = optimize(
#         master_problem; optimizer = mip_optimizer, update_problem = false
#     )
#     end
#     if primal_sol != nothing
#         @logmsg LogLevel(-2) "Restricted Master Heur found sol: $primal_sol"
#     else
#         primal_sol = PrimalSolution()
#         @logmsg LogLevel(-2) "Restricted Master Heur did not find a feasible solution"
#     end
#     alg.sols_and_bounds.alg_inc_ip_primal_bound = primal_sol.cost
#     alg.sols_and_bounds.alg_inc_ip_primal_sol_map = primal_sol.var_val_map
#     switch_primary_secondary_moi_def(master_problem)

#     end
# end

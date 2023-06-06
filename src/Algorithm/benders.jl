"""
    Coluna.Algorithm.BendersCutGeneration(
        restr_master_solve_alg = SolveLpForm(get_dual_solution = true, relax_integrality = true),
        restr_master_optimizer_id = 1,
        feasibility_tol::Float64 = 1e-5,
        optimality_tol::Float64 = Coluna.DEF_OPTIMALITY_ATOL,
        max_nb_iterations::Int = 100,
        separation_solve_alg = SolveLpForm(get_dual_solution = true, relax_integrality = true)
    )

Benders cut generation algorithm that can be applied to a formulation reformulated using
Benders decomposition.
"""
@with_kw struct BendersCutGeneration <: AbstractOptimizationAlgorithm
    restr_master_solve_alg = SolveLpForm(get_dual_solution = true, relax_integrality = true)
    restr_master_optimizer_id = 1
    feasibility_tol::Float64 = 1e-5
    optimality_tol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    max_nb_iterations::Int = 100
    separation_solve_alg = SolveLpForm(get_dual_solution = true, relax_integrality = true)
    print::Bool = true
    debug_print_master::Bool = false
    debug_print_master_primal_solution::Bool = false
    debug_print_master_dual_solution::Bool = false
    debug_print_subproblem::Bool = false
    debug_print_subproblem_primal_solution::Bool = false
    debug_print_subproblem_dual_solution::Bool = false
    debug_print_generated_cuts::Bool = false
end

# TO DO : BendersCutGeneration does not have yet the child algorithms
# it should have at least the algorithm to solve the master LP and the algorithms
# to solve the subproblems

function get_units_usage(algo::BendersCutGeneration, reform::Reformulation) 
    units_usage = Tuple{AbstractModel, UnitType, UnitPermission}[] 
    master = getmaster(reform)
    push!(units_usage, (master, MasterCutsUnit, READ_AND_WRITE))

    # TO DO : everything else should be communicated by the child algorithms 
    #push!(units_usage, (master, StaticVarConstrUnit, READ_ONLY))
    push!(units_usage, (master, MasterBranchConstrsUnit, READ_ONLY))
    push!(units_usage, (master, MasterColumnsUnit, READ_ONLY))
    # for (id, spform) in get_benders_sep_sps(reform)
    #     #push!(units_usage, (spform, StaticVarConstrUnit, READ_ONLY))
    # end
    return units_usage
end

function _new_context(C::Type{<:Benders.AbstractBendersContext}, reform, algo)
    return C(reform, algo)
end

# TODO: fis this method
function _benders_optstate_output(result, master)
    optstate = OptimizationState(master)

    if result.infeasible
        setterminationstatus!(optstate, INFEASIBLE)
    end

    if !isnothing(result.ip_primal_sol)
        set_lp_primal_sol!(optstate, result.ip_primal_sol)
    end

    if !isnothing(result.mlp)
        set_lp_dual_bound!(optstate, DualBound(master, result.mlp))
        set_ip_dual_bound!(optstate, DualBound(master, result.mlp))
        set_lp_primal_bound!(optstate, PrimalBound(master, result.mlp))
    end
    return optstate
end

function run!(
    algo::BendersCutGeneration, env::Env, reform::Reformulation, input::OptimizationState
)
    ctx = Coluna.Algorithm.BendersPrinterContext(
        reform, algo;
        print = true,
        debug_print_master = algo.debug_print_master,
        debug_print_master_primal_solution = algo.debug_print_master_primal_solution,
        debug_print_master_dual_solution = algo.debug_print_master_dual_solution,
        debug_print_subproblem = algo.debug_print_subproblem,
        debug_print_subproblem_primal_solution = algo.debug_print_subproblem_primal_solution,
        debug_print_subproblem_dual_solution = algo.debug_print_subproblem_dual_solution,
        debug_print_generated_cuts = algo.debug_print_generated_cuts
    )
    result = Benders.run_benders_loop!(ctx, env)
    return _benders_optstate_output(result, getmaster(reform))
end

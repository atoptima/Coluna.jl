"""
    Coluna.Algorithm.ColumnGeneration(
        restr_master_solve_alg = SolveLpForm(get_dual_solution = true),
        pricing_prob_solve_alg = SolveIpForm(
            moi_params = MoiOptimize(
                deactivate_artificial_vars = false,
                enforce_integrality = false
            )
        ),
        essential_cut_gen_alg = CutCallbacks(call_robust_facultative = false),
        max_nb_iterations = 1000,
        log_print_frequency = 1,
        redcost_tol = 1e-4,
        show_column_already_inserted_warning = true,
        cleanup_threshold = 10000,
        cleanup_ratio = 0.66,
        smoothing_stabilization = 0.0 # should be in [0, 1],
    )

Column generation algorithm that can be applied to formulation reformulated using
Dantzig-Wolfe decomposition. 

This algorithm first solves the linear relaxation of the master (master LP) using `restr_master_solve_alg`.
Then, it solves the subproblems by calling `pricing_prob_solve_alg` to get the columns that
have the best reduced costs and that hence, may improve the master LP's objective the most.

In order for the algorithm to converge towards the optimal solution of the master LP,
it suffices that the pricing oracle returns, at each iteration, a negative reduced cost solution if one exists. 
The algorithm stops when all subproblems fail to generate a column with negative
(positive) reduced cost in the case of a minimization (maximization) problem or when it
reaches the maximum number of iterations.

Parameters : 
- `restr_master_solve_alg`: algorithm to optimize the master LP
- `pricing_prob_solve_alg`: algorithm to optimize the subproblems
- `essential_cut_gen_alg`: algorithm to generate essential cuts which is run when the solution of the master LP is integer.

Options:
- `max_nb_iterations`: maximum number of iterations
- `log_print_frequency`: display frequency of iterations statistics

Undocumented parameters are in alpha version.

## About the ouput

At each iteration (depending on `log_print_frequency`), 
the column generation algorithm can display following statistics.

    <it= 90> <et=15.62> <mst= 0.02> <sp= 0.05> <cols= 4> <al= 0.00> <DB=  300.2921> <mlp=  310.3000> <PB=310.3000>

Here are their meanings :
- `it` stands for the current number of iterations of the algorithm
- `et` is the elapsed time in seconds since Coluna has started the optimisation
- `mst` is the time in seconds spent solving the master LP at the current iteration
- `sp` is the time in seconds spent solving the subproblems at the current iteration
- `cols` is the number of column generated by the subproblems at the current iteration
- `al` is the smoothing factor of the stabilisation at the current iteration (alpha version)
- `DB` is the dual bound of the master LP at the current iteration
- `mlp` is the objective value of the master LP at the current iteration
- `PB` is the objective value of the best primal solution found by Coluna at the current iteration
"""
@with_kw struct ColumnGeneration <: AbstractOptimizationAlgorithm
    restr_master_solve_alg = SolveLpForm(get_dual_solution=true)
    restr_master_optimizer_id = 1
    # TODO : pricing problem solver may be different depending on the
    #       pricing subproblem
    pricing_prob_solve_alg = SolveIpForm(
        moi_params = MoiOptimize(
            deactivate_artificial_vars = false,
            enforce_integrality = false
        )
    )
    stages_pricing_solver_ids = [1]
    essential_cut_gen_alg = CutCallbacks(call_robust_facultative=false)
    max_nb_iterations::Int64 = 1000
    log_print_frequency::Int64 = 1
    store_all_ip_primal_sols::Bool = false
    redcost_tol::Float64 = 1e-4
    show_column_already_inserted_warning = true
    throw_column_already_inserted_warning = false
    solve_subproblems_parallel::Bool = false
    cleanup_threshold::Int64 = 10000
    cleanup_ratio::Float64 = 0.66
    smoothing_stabilization::Float64 = 0.0 # should be in [0, 1]
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL
    print::Bool = true
end

stabilization_is_used(algo::ColumnGeneration) = !iszero(algo.smoothing_stabilization)

############################################################################################
# Implementation of Algorithm interface.
############################################################################################

function get_child_algorithms(algo::ColumnGeneration, reform::Reformulation) 
    child_algs = Tuple{AlgoAPI.AbstractAlgorithm,AbstractModel}[]
    push!(child_algs, (algo.restr_master_solve_alg, getmaster(reform)))
    push!(child_algs, (algo.essential_cut_gen_alg, getmaster(reform)))
    for (id, spform) in get_dw_pricing_sps(reform)
        push!(child_algs, (algo.pricing_prob_solve_alg, spform))
    end
    return child_algs
end

function get_units_usage(algo::ColumnGeneration, reform::Reformulation) 
    units_usage = Tuple{AbstractModel,UnitType,UnitPermission}[] 
    master = getmaster(reform)
    push!(units_usage, (master, MasterColumnsUnit, READ_AND_WRITE))
    push!(units_usage, (master, MasterBasisUnit, READ_AND_WRITE))
    #push!(units_usage, (master, PartialSolutionUnit, READ_ONLY))
    if stabilization_is_used(algo)
        push!(units_usage, (master, ColGenStabilizationUnit, READ_AND_WRITE))
    end
    return units_usage
end

############################################################################################
# Column generation algorithm.
############################################################################################

function _colgen_context(algo::ColumnGeneration)
    algo.print && return ColGenPrinterContext
    return ColGenContext
end

function _new_context(C::Type{<:ColGen.AbstractColGenContext}, reform, algo)
    return C(reform, algo)
end

function _colgen_optstate_output(result, master)
    optstate = OptimizationState(master)

    if result.infeasible
        setterminationstatus!(optstate, INFEASIBLE)
    end

    if !isnothing(result.master_lp_primal_sol)
        set_lp_primal_sol!(optstate, result.master_lp_primal_sol)
    end

    if !isnothing(result.master_ip_primal_sol)
        update_ip_primal_sol!(optstate, result.master_ip_primal_sol)
    end

    if !isnothing(result.master_lp_dual_sol)
        update_lp_dual_sol!(optstate, result.master_lp_dual_sol)
    end

    if !isnothing(result.db)
        set_lp_dual_bound!(optstate, DualBound(master, result.db))
        set_ip_dual_bound!(optstate, DualBound(master, result.db))
    end

    if !isnothing(result.mlp)
        set_lp_primal_bound!(optstate, PrimalBound(master, result.mlp))
    end
    return optstate
end

function run!(algo::ColumnGeneration, env::Env, reform::Reformulation, input::OptimizationState)
    C = _colgen_context(algo)
    ctx = _new_context(C, reform, algo)
    result = ColGen.run!(ctx, env, get_best_ip_primal_sol(input))

    master = getmaster(reform)
    
    return _colgen_optstate_output(result, master)
end

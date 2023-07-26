"""
    Coluna.Algorithm.BendersCutGeneration(
        restr_master_solve_alg = SolveLpForm(get_dual_sol = true, relax_integrality = true),
        restr_master_optimizer_id = 1,
        separation_solve_alg = SolveLpForm(get_dual_sol = true, relax_integrality = true)
        max_nb_iterations::Int = 100,
    )

Benders cut generation algorithm that can be applied to a formulation reformulated using
Benders decomposition.

This algorithm is an implementation of the generic algorithm provided by the `Benders`
submodule.

**Parameters:**
- `restr_master_solve_alg`: algorithm to solve the restricted master problem
- `restr_master_optimizer_id`: optimizer id to use to solve the restricted master problem
- `separation_solve_alg`: algorithm to solve the separation problem (must be a LP solver that returns a dual solution)

**Option:**
- `max_nb_iterations`: maximum number of iterations

## About the output

At each iteration, the Benders cut generation algorithm show following statistics:

    <it=  6> <et= 0.05> <mst= 0.00> <sp= 0.00> <cuts= 0> <master=  293.5000>

where:
- `it` stands for the current number of iterations of the algorithm
- `et` is the elapsed time in seconds since Coluna has started the optimisation
- `mst` is the time in seconds spent solving the master problem at the current iteration
- `sp` is the time in seconds spent solving the separation problem at the current iteration
- `cuts` is the number of cuts generated at the current iteration
- `master` is the objective value of the master problem at the current iteration

**Debug options** (print at each iteration):
- `debug_print_master`: print the master problem
- `debug_print_master_primal_solution`: print the master problem with the primal solution
- `debug_print_master_dual_solution`: print the master problem with the dual solution (make sure the `restr_master_solve_alg` returns a dual solution)
- `debug_print_subproblem`: print the subproblem
- `debug_print_subproblem_primal_solution`: print the subproblem with the primal solution
- `debug_print_subproblem_dual_solution`: print the subproblem with the dual solution
- `debug_print_generated_cuts`: print the generated cuts
"""
struct BendersCutGeneration <: AbstractOptimizationAlgorithm
    restr_master_solve_alg::Union{SolveLpForm, SolveIpForm}
    restr_master_optimizer_id::Int
    feasibility_tol::Float64
    optimality_tol::Float64
    max_nb_iterations::Int
    separation_solve_alg::SolveLpForm
    print::Bool
    debug_print_master::Bool
    debug_print_master_primal_solution::Bool
    debug_print_master_dual_solution::Bool
    debug_print_subproblem::Bool
    debug_print_subproblem_primal_solution::Bool
    debug_print_subproblem_dual_solution::Bool
    debug_print_generated_cuts::Bool
    BendersCutGeneration(;
        restr_master_solve_alg = SolveLpForm(get_dual_sol = true, relax_integrality = true),
        restr_master_optimizer_id = 1,
        feasibility_tol = 1e-5,
        optimality_tol = Coluna.DEF_OPTIMALITY_ATOL,
        max_nb_iterations = 100,
        separation_solve_alg = SolveLpForm(get_dual_sol = true, relax_integrality = true),
        print = true,
        debug_print_master = false,
        debug_print_master_primal_solution = false,
        debug_print_master_dual_solution = false,
        debug_print_subproblem = false,
        debug_print_subproblem_primal_solution = false,
        debug_print_subproblem_dual_solution = false,
        debug_print_generated_cuts = false
    ) = new(
        restr_master_solve_alg,
        restr_master_optimizer_id,
        feasibility_tol,
        optimality_tol,
        max_nb_iterations,
        separation_solve_alg,
        print,
        debug_print_master,
        debug_print_master_primal_solution,
        debug_print_master_dual_solution,
        debug_print_subproblem,
        debug_print_subproblem_primal_solution,
        debug_print_subproblem_dual_solution,
        debug_print_generated_cuts
    )
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

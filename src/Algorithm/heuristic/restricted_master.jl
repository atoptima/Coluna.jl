"""
The restricted master heuristic enforces integrality of the master column variables and 
optimizes the master problem restricted to active master column variables using a MIP solver.
If the heuristic finds a solution, it checks that this solution does not violate any essential
cut.
"""
struct RestrictedMasterHeuristic <: AbstractOptimizationAlgorithm
    solve_ip_form_alg::SolveIpForm

    RestrictedMasterHeuristic(;
        solve_ip_form_alg = SolveIpForm(moi_params = MoiOptimize(get_dual_bound = false))
    ) = new(solve_ip_form_alg)
end

ismanager(::RestrictedMasterHeuristic) = false

function get_child_algorithms(algo::RestrictedMasterHeuristic, reform::Reformulation)
    child_algs = Dict{String, Tuple{AlgoAPI.AbstractAlgorithm, MathProg.Formulation}}(
        "solve_ip_form_alg" => (algo.solve_ip_form_alg, getmaster(reform))
    ) 
    return child_algs
end

# struct RestrictedMasterHeuristicOutput <: Heuristic.AbstractHeuristicOutput
#     ip_primal_sols::Vector{PrimalSolution}
# end

# Heuristic.get_primal_sols(o::RestrictedMasterHeuristicOutput) = o.ip_primal_sols

function run!(algo::RestrictedMasterHeuristic, env, reform, input::OptimizationState)
    master = getmaster(reform)
    ip_form_output = run!(algo.solve_ip_form_alg, env, master, input)
    ip_primal_sols = get_ip_primal_sols(ip_form_output)

    output = OptimizationState(master)

    # We need to make sure that the solution is feasible by separating essential cuts and then
    # project the solution on master.
    if length(ip_primal_sols) > 0
        for sol in sort(ip_primal_sols) # we start with worst solution to add all improving solutions
            cutgen = CutCallbacks(call_robust_facultative = false)
            cutcb_output = run!(cutgen, env, master, CutCallbacksInput(sol))
            if cutcb_output.nb_cuts_added == 0
                add_ip_primal_sol!(output, sol)
            end
        end
    end
    return output
end

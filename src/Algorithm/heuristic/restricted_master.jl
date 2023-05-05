"""
The restricted master heuristic enforces integrality of the master column variables and 
optimizes the master problem restricted to active master column variables using a MIP solver.
If the heuristic finds a solution, it checks that this solution does not violate any essential
cut.
"""
struct RestrictedMasterHeuristic <: Heuristic.AbstractHeuristic end

ismanager(::RestrictedMasterHeuristic) = false

struct RestrictedMasterHeuristicOutput <: Heuristic.AbstractHeuristicOutput
    ip_primal_sols::Vector{PrimalSolution}
end

Heuristic.get_primal_sols(o::RestrictedMasterHeuristicOutput) = o.ip_primal_sols

function Heuristic.run(::RestrictedMasterHeuristic, env, master, cur_inc_primal_sol)
    solve_ip_form = SolveIpForm(moi_params = MoiOptimize(get_dual_bound = false))
   
    input = OptimizationState(master)
    if !isnothing(cur_inc_primal_sol)
        update_ip_primal_sol!(input, cur_inc_primal_sol)
    end

    ip_form_output = run!(solve_ip_form, env, master, input)
    return RestrictedMasterHeuristicOutput(get_ip_primal_sols(ip_form_output))
end

function AlgoAPI.run!(::RestrictedMasterHeuristic, env, master, cur_inc_primal_sol)
    output = Heuristic.run(RestrictedMasterHeuristic(), env, master, cur_inc_primal_sol)
    ip_primal_sols = Heuristic.get_primal_sols(output)

    # We need to make sure that the solution is feasible by separating essential cuts and then
    # project the solution on master.
    feasible_ip_primal_sols = PrimalSolution[]
    if length(ip_primal_sols) > 0
        for sol in sort(ip_primal_sols) # we start with worst solution to add all improving solutions
            cutgen = CutCallbacks(call_robust_facultative = false)
            cutcb_output = run!(cutgen, env, master, CutCallbacksInput(sol))
            if cutcb_output.nb_cuts_added == 0
                push!(feasible_ip_primal_sols, sol)
            end
        end
    end
    return RestrictedMasterHeuristicOutput(feasible_ip_primal_sols)
end
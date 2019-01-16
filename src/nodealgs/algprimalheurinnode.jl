@hl mutable struct AlgToPrimalHeurInNode <: AlgLike
    sols_and_bounds::SolsAndBounds
    extended_problem::ExtendedProblem
end

AlgToPrimalHeurInNodeBuilder(prob::ExtendedProblem) = (SolsAndBounds(), prob)

function setup(alg::AlgToPrimalHeurInNode)
    return false
end

function setdown(alg::AlgToPrimalHeurInNode)
    return false
end

@hl mutable struct AlgToPrimalHeurByRestrictedMip <: AlgToPrimalHeurInNode end

AlgToPrimalHeurByRestrictedMipBuilder(prob::ExtendedProblem) =
        AlgToPrimalHeurInNodeBuilder(prob)

function run(alg::AlgToPrimalHeurByRestrictedMip, node::Node,
             global_treat_order::Int)

    master_prob = alg.extended_problem.master_problem
    mip_optimizer = GLPK.Optimizer()
    load_problem_in_optimizer(master_prob, mip_optimizer, false)
    sols = optimize(master_prob, mip_optimizer)
    primal_sol = sols[2]
    @logmsg LogLevel(-2) "Restricted Master Heur found sol: $primal_sol"
    alg.sols_and_bounds.alg_inc_ip_primal_bound = primal_sol.cost
    alg.sols_and_bounds.alg_inc_ip_primal_sol_map = primal_sol.var_val_map
    if primal_sol.cost < node.node_inc_ip_primal_bound
        record_ip_primal_sol_and_update_ip_primal_bound(node,
                                                        alg.sols_and_bounds)
    end
    println("<restricted master ip heur> ", "<mip=$(primal_sol.cost)> ",
            "<PB=$(node.node_inc_ip_primal_bound)>")
end

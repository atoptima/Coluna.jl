@hl mutable struct AlgToPrimalHeurInNode <: AlgLike
    sols_and_bounds::SolsAndBounds
    extended_problem::ExtendedProblem
end

AlgToPrimalHeurInNodeBuilder(prob::ExtendedProblem) = (SolsAndBounds(), prob)

@hl mutable struct AlgToPrimalHeurByRestrictedMip <: AlgToPrimalHeurInNode
    optimizer_type::DataType
end

AlgToPrimalHeurByRestrictedMipBuilder(prob::ExtendedProblem,
                                      solver_type::DataType) =
        tuplejoin(AlgToPrimalHeurInNodeBuilder(prob), solver_type)

function run(alg::AlgToPrimalHeurByRestrictedMip, global_treat_order::Int,
             primal_sol::PrimalSolution)
    @timeit to(alg) "Restricted master IP" begin

    @timeit to(alg) "Setup of optimizer" begin
    master_problem = alg.extended_problem.master_problem
    switch_primary_secondary_moi_def(master_problem)
    mip_optimizer = alg.optimizer_type()
    load_problem_in_optimizer(master_problem, mip_optimizer, false)
    end
    @timeit to(alg) "Solving" begin
    sols = optimize(master_problem, mip_optimizer)
    end
    if sols[2] != nothing
        primal_sol = sols[2]
        @logmsg LogLevel(-2) "Restricted Master Heur found sol: $primal_sol"
    else
        primal_sol = PrimalSolution()
        @logmsg LogLevel(-2) "Restricted Master Heur did not find a feasible solution"
    end
    alg.sols_and_bounds.alg_inc_ip_primal_bound = primal_sol.cost
    alg.sols_and_bounds.alg_inc_ip_primal_sol_map = primal_sol.var_val_map
    switch_primary_secondary_moi_def(master_problem)

    end
end

@hl mutable struct AlgToPrimalHeurBySimpleDiving <: AlgToPrimalHeurInNode 
    diving_root_node::DivingNode
end

function AlgToPrimalHeurBySimpleDivingBuilder(prob::ExtendedProblem, dual_bound::Float,
                           problem_setup_info::SetupInfo)
    return tuplejoin(AlgToPrimalHeurInNodeBuilder(prob), 
                     DivingNodeBuilder(problem, dual_bound, problem_setup_info))
end

function run(alg::AlgToPrimalHeurBySimpleDiving, global_treat_order::Int, 
             primal_sol::PrimalSolution)

    nb_treated_nodes = 0
    treat_algs = TreatAlgs()

    (col, col_val) = select_master_col_to_fix(alg, primal_sol)
    cur_node = DivingNodeWithParent(alg.extended_problem, alg.diving_root_node, (col, col_val))
    while true
        if prepare_node_for_treatment(alg.extended_problem, cur_diving_node,
                                      treat_algs, global_treat_order)

            if !treat(cur_node, treat_algs, global_treat_order,
                      alg.extended_problem.primal_inc_bound)
                println("error: diving is interrupted")
                break
            end
            global_nodes_treat_order += 1
            nb_treated_nodes += 1
        end

        if (cur_node.infeasible
            || cur_node.ip_primal_bound_is_updated)
            break
        else
            cur_node = cur_node.children[1]
        end
    end

    if cur_node.ip_primal_bound_is_updated
        alg.sols_and_bounds.alg_inc_ip_primal_bound =  cur_node.node_inc_ip_primal_bound 
        alg.sols_and_bounds.alg_inc_ip_primal_sol_map = cur_node.node_inc_ip_primal_sol.var_val_map
    end

    return nb_treated_nodes
end

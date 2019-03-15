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

function run(alg::AlgToPrimalHeurByRestrictedMip, global_treat_order::TreatOrder,
             primal_sol::PrimalSolution)
    @timeit to(alg) "Restricted master IP" begin

    @timeit to(alg) "Setup of optimizer" begin
    master_problem = alg.extended_problem.master_problem
    switch_primary_secondary_moi_def(master_problem)
    mip_optimizer = alg.optimizer_type()
    load_problem_in_optimizer(master_problem, mip_optimizer, false)
    end
    @timeit to(alg) "Solving" begin
    status, primal_sol, dual_sol = optimize(
        master_problem; optimizer = mip_optimizer, update_problem = false
    )
    end
    if primal_sol != nothing
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
    bcp_node::Node
    diving_root_node::DivingNode
end

function AlgToPrimalHeurBySimpleDivingBuilder(prob::ExtendedProblem, dual_bound::Float,
                           problem_setup_info::SetupInfo, bcp_node::Node)

     return tuplejoin(AlgToPrimalHeurInNodeBuilder(prob), bcp_node, 
                      DivingNode(prob, dual_bound, problem_setup_info, PrimalSolution()))
end

function update_diving_root_node(alg::AlgToPrimalHeurBySimpleDiving, 
                                 global_treat_order::TreatOrder, primal_sol::PrimalSolution)
    root = alg.diving_root_node
    root.problem_setup_info = deepcopy(alg.bcp_node.problem_setup_info)
    root.node_inc_lp_dual_bound = primal_sol.cost
    root.node_inc_ip_dual_bound = primal_sol.cost
    root.node_inc_lp_primal_bound = alg.extended_problem.primal_inc_bound
    root.node_inc_ip_primal_bound = alg.extended_problem.primal_inc_bound
    root.primal_sol = primal_sol
    root.evaluated = true
end

function run(alg::AlgToPrimalHeurBySimpleDiving, global_treat_order::TreatOrder, 
             primal_sol::PrimalSolution)

    nb_treated_nodes = 0
    treat_algs = TreatAlgs()

    update_diving_root_node(alg, global_treat_order, primal_sol)
    cur_node = alg.diving_root_node
    while true
        if prepare_node_for_treatment(alg.extended_problem, cur_node,
                                      treat_algs, global_treat_order)

            if !treat(cur_node, treat_algs, global_treat_order,
                      alg.extended_problem.primal_inc_bound)
                println("error: diving is interrupted")
                break
            end
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
        var_val_map = Dict{Variable, Float}()
        #columns of master sol
        for (var, val) in cur_node.node_inc_ip_primal_sol.var_val_map
            var_val_map[var] = val
        end
        #columns of master partial sol
        for (var, val) in alg.extended_problem.master_problem.partial_solution.var_val_map
            if haskey(var_val_map, var)
                var_val_map[var] += val
            else
                var_val_map[var] = val
            end
        end
        alg.sols_and_bounds.alg_inc_ip_primal_bound =  cur_node.node_inc_ip_primal_bound 
        alg.sols_and_bounds.alg_inc_ip_primal_sol_map = var_val_map
    end

    return nb_treated_nodes
end

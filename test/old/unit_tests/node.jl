function node_unit_tests()

    node_tests()
    node_with_parent_tests()
    is_conquered_tests()
    is_to_be_pruned_tests()
    exit_treatment_tests()
    mark_infeasible_and_exit_treatment_tests()
    record_ip_primal_sol_and_update_ip_primal_bound_tests()
    update_node_duals_tests()
    update_node_primals_tets()
    update_node_incumbents_tests()
    evaluation_tests()
    treat_tests()

end

function node_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    @test node.depth == 0
end

function node_with_parent_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    node_with_parent = CL.NodeWithParent(extended_problem, node)
    @test node_with_parent.parent == node
end

function is_conquered_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    node.node_inc_ip_primal_bound = 0.0
    node.node_inc_ip_dual_bound = 0.0
    node.params.mip_tolerance_integrality = 0.0
    @test CL.is_conquered(node) == true
    node.node_inc_ip_primal_bound = 1.00001
    node.node_inc_ip_dual_bound = 1.0
    node.params.mip_tolerance_integrality = 0.000001
    @test CL.is_conquered(node) == false
    node.node_inc_ip_primal_bound = 10.0
    node.node_inc_ip_dual_bound = 11.0
    node.params.mip_tolerance_integrality = 0.0
    @test CL.is_conquered(node) == true
end

function is_to_be_pruned_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    primal_bound = 0.0
    node.node_inc_ip_dual_bound = 0.0
    node.params.mip_tolerance_integrality = 0.0
    @test CL.is_to_be_pruned(node, primal_bound) == true
    primal_bound = 1.00001
    node.node_inc_ip_dual_bound = 1.0
    node.params.mip_tolerance_integrality = 0.000001
    @test CL.is_to_be_pruned(node, primal_bound) == false
    primal_bound = 10.0
    node.node_inc_ip_dual_bound = 11.0
    node.params.mip_tolerance_integrality = 0.0
    @test CL.is_to_be_pruned(node, primal_bound) == true
end

function exit_treatment_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    CL.exit_treatment(node)
    @test node.evaluated == true
    @test node.treated == true
end

function mark_infeasible_and_exit_treatment_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    CL.mark_infeasible_and_exit_treatment(node)
    @test node.infeasible == true
    node.node_inc_lp_dual_bound = node.node_inc_ip_dual_bound == Inf
end

function record_ip_primal_sol_and_update_ip_primal_bound_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    sols_and_bounds = create_sols_and_bounds(2)
    sols_and_bounds.alg_inc_ip_primal_bound = 10.0
    node.node_inc_ip_dual_bound = 12.0
    CL.record_ip_primal_sol_and_update_ip_primal_bound(node, sols_and_bounds)
    @test node.node_inc_ip_primal_bound == sols_and_bounds.alg_inc_ip_primal_bound
    @test node.node_inc_ip_primal_sol.var_val_map == sols_and_bounds.alg_inc_ip_primal_sol_map
    @test node.ip_primal_bound_is_updated == true
end

function update_node_duals_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    sols_and_bounds = create_sols_and_bounds(2)
    node.node_inc_ip_dual_bound = 10.0
    node.node_inc_lp_dual_bound = 10.0
    sols_and_bounds.alg_inc_ip_dual_bound = 13.0
    sols_and_bounds.alg_inc_lp_dual_bound = 12.0
    CL.update_node_duals(node, sols_and_bounds)
    @test node.dual_bound_is_updated == true
    @test node.node_inc_lp_dual_bound == sols_and_bounds.alg_inc_lp_dual_bound
    @test node.node_inc_ip_dual_bound == sols_and_bounds.alg_inc_ip_dual_bound
end

function update_node_primals_tets()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    sols_and_bounds = create_sols_and_bounds(2)
    sols_and_bounds.is_alg_inc_ip_primal_bound_updated = true
    sols_and_bounds.alg_inc_ip_primal_bound = 10.0
    sols_and_bounds.alg_inc_lp_primal_bound = 10.0
    node.node_inc_ip_dual_bound = 12.0
    CL.update_node_primals(node, sols_and_bounds)
    @test node.node_inc_lp_primal_bound == sols_and_bounds.alg_inc_lp_primal_bound
    @test node.node_inc_ip_primal_bound == sols_and_bounds.alg_inc_ip_primal_bound
    @test node.node_inc_ip_primal_sol.var_val_map == sols_and_bounds.alg_inc_ip_primal_sol_map
    @test node.primal_sol.var_val_map == sols_and_bounds.alg_inc_lp_primal_sol_map
    @test node.ip_primal_bound_is_updated == true
end

function update_node_incumbents_tests()
    extended_problem = create_extended_problem()
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    sols_and_bounds = create_sols_and_bounds(2)
    sols_and_bounds.is_alg_inc_ip_primal_bound_updated = true
    sols_and_bounds.alg_inc_ip_primal_bound = 10.0
    sols_and_bounds.alg_inc_lp_primal_bound = 10.0
    node.node_inc_ip_dual_bound = 12.0
    node.node_inc_lp_dual_bound = 10.0
    sols_and_bounds.alg_inc_ip_dual_bound = 13.0
    sols_and_bounds.alg_inc_lp_dual_bound = 12.0
    CL.update_node_incumbents(node, sols_and_bounds)
    @test node.node_inc_lp_primal_bound == sols_and_bounds.alg_inc_lp_primal_bound
    @test node.node_inc_ip_primal_bound == sols_and_bounds.alg_inc_ip_primal_bound
    @test node.node_inc_ip_primal_sol.var_val_map == sols_and_bounds.alg_inc_ip_primal_sol_map
    @test node.primal_sol.var_val_map == sols_and_bounds.alg_inc_lp_primal_sol_map
    @test node.ip_primal_bound_is_updated == true
    @test node.dual_bound_is_updated == true
    @test node.node_inc_lp_dual_bound == sols_and_bounds.alg_inc_lp_dual_bound
    @test node.node_inc_ip_dual_bound == sols_and_bounds.alg_inc_ip_dual_bound
end

function evaluation_tests()
    # # Tests if exits correctly in the firs if
    # treat_algs.alg_setup_node = DummySetupFail()
    # try CL.evaluation(node, treat_algs, 1, 0.0)
    #     error("Setup did not fail")
    # catch err
    #     @test err == ErrorException("Setups cannot fail")
    # end
    # # Tests if exits correctly in the second if

    # Tests if exists correctly if problem is infeasible
    extended_problem = create_extended_problem()
    extended_problem.master_problem, vars, constrs = create_problem_knapsack(false)
    node = create_node(extended_problem, false)
    treat_algs = CL.TreatAlgs()
    treat_algs.alg_setup_node = CL.AlgToSetupRootNode(extended_problem,
        node.problem_setup_info)
    treat_algs.alg_setdown_node = CL.AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = CL.UsualBranchingAlg(extended_problem)
    treat_algs.alg_eval_node = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.evaluation(node, treat_algs, 1, 0.0) == true
    @test node.evaluated == true
    @test node.treated == true
    @test node.infeasible == true
    @test node.node_inc_lp_dual_bound == Inf
    @test node.node_inc_ip_dual_bound == Inf

    # Tests when node is conquered
    extended_problem = create_extended_problem()
    extended_problem.master_problem, vars, constrs = create_problem_knapsack(true, false)
    node = create_node(extended_problem, false)
    treat_algs = CL.TreatAlgs()
    treat_algs.alg_setup_node = CL.AlgToSetupRootNode(extended_problem,
        node.problem_setup_info)
    treat_algs.alg_setdown_node = CL.AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = CL.UsualBranchingAlg(extended_problem)
    treat_algs.alg_eval_node = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    @test CL.evaluation(node, treat_algs, 1, 0.0) == true
    @test CL.is_conquered(node) == true
    @test node.evaluated == true
    @test node.treated == true
    @test node.infeasible == false
    @test node.node_inc_lp_primal_bound == -11.0
    @test node.node_inc_ip_primal_bound == -11.0
    @test node.node_inc_lp_dual_bound == -11.0
    @test node.node_inc_ip_dual_bound == -11.0

    # Tests when node is not conquered
    atol = rtol = 0.000001
    extended_problem = create_extended_problem()
    extended_problem.master_problem, vars, constrs = create_problem_knapsack(true, false, true)
    node = create_node(extended_problem, false)
    treat_algs = CL.TreatAlgs()
    treat_algs.alg_setup_node = CL.AlgToSetupRootNode(extended_problem,
        node.problem_setup_info)
    treat_algs.alg_setdown_node = CL.AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = CL.UsualBranchingAlg(extended_problem)
    treat_algs.alg_eval_node = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.evaluation(node, treat_algs, 1, 0.0) == true
    @test CL.is_conquered(node) == false
    @test node.evaluated == true
    @test node.treated == false
    @test node.infeasible == false
    @test node.node_inc_lp_primal_bound ≈ -11.666666666 atol=atol rtol=rtol
    @test node.node_inc_ip_primal_bound ≈ -11.666666666 atol=atol rtol=rtol
    @test length(node.problem_setup_info.active_branching_constraints_info) == 0
    @test length(node.children) == 0

end

function treat_tests()

    # Tests if exists correctly if problem is infeasible
    extended_problem = create_extended_problem()
    extended_problem.master_problem, vars, constrs = create_problem_knapsack(false)
    node = create_node(extended_problem, false)
    treat_algs = CL.TreatAlgs()
    treat_algs.alg_setup_node = CL.AlgToSetupRootNode(extended_problem,
        node.problem_setup_info)
    treat_algs.alg_setdown_node = CL.AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = CL.UsualBranchingAlg(extended_problem)
    treat_algs.alg_eval_node = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.treat(node, treat_algs, 1, 0.0) == true
    @test node.evaluated == true
    @test node.treated == true
    @test node.infeasible == true
    @test node.node_inc_lp_dual_bound == Inf
    @test node.node_inc_ip_dual_bound == Inf
    @test length(node.children) == 0

    # Tests when node is not conquered
    atol = rtol = 0.000001
    extended_problem = create_extended_problem()
    extended_problem.master_problem, vars, constrs = create_problem_knapsack(true, false, true)
    node = create_node(extended_problem, false)
    treat_algs = CL.TreatAlgs()
    treat_algs.alg_setup_node = CL.AlgToSetupRootNode(extended_problem,
        node.problem_setup_info)
    treat_algs.alg_setdown_node = CL.AlgToSetdownNodeFully(extended_problem)
    treat_algs.alg_generate_children_nodes = CL.UsualBranchingAlg(extended_problem)
    treat_algs.alg_eval_node = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.treat(node, treat_algs, 1, 0.0) == true
    @test CL.is_conquered(node) == false
    @test node.evaluated == true
    @test node.treated == true
    @test node.infeasible == false
    @test node.node_inc_lp_primal_bound ≈ -11.666666666 atol=atol rtol=rtol
    @test node.node_inc_ip_primal_bound ≈ -11.666666666 atol=atol rtol=rtol
    @test length(node.children) == 2

end

function node_unit_tests()

    node_tests()
    node_with_parent_tests()
    is_conquered_tests()
    is_to_be_pruned_tests()

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

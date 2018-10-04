function alg_generate_children_nodes_unit_tests()

    alg_generate_children_nodes_tests()
    usual_branching_alg_tests()
    alg_generate_children_setdown_tests()
    sort_vars_according_to_rule_tests()
    retreive_candidate_vars_tests()
    generate_branch_constraint_tests()
    generate_child_tests()
    perform_usual_branching_tests()

end

function alg_generate_children_nodes_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToGenerateChildrenNodes(extended_problem)
    @test alg.extended_problem === extended_problem
end

function usual_branching_alg_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    @test alg.extended_problem === extended_problem
    @test alg.rule == CL.MostFractionalRule()
end

function alg_generate_children_setup_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    @test CL.setup(alg) == false
end

function alg_generate_children_setdown_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    @test CL.setdown(alg) == nothing
end

function sort_vars_according_to_rule_tests()
    rule = CL.MostFractionalRule()
    vars = create_array_of_vars(3, CL.Variable)
    vals = [4.0, 3.6, 2.5]
    pairs = [Pair{CL.Variable,Float64}(vars[i],vals[i]) for i in 1:length(vars)]
    CL.sort_vars_according_to_rule(rule, pairs)
    @test pairs[1].first == vars[3]
    @test pairs[2].first == vars[2]
    @test pairs[3].first == vars[1]
end

function retreive_candidate_vars_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    vars = create_array_of_vars(3, CL.MasterVar)
    var_val_map = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.01, vars[3] => 3.00001)
    candidate_vars = CL.retreive_candidate_vars(alg, var_val_map)
    @test findfirst(x->x.first==vars[1], candidate_vars) == nothing
    @test findfirst(x->x.first==vars[2], candidate_vars) != nothing
    @test findfirst(x->x.first==vars[3], candidate_vars) != nothing
end

function generate_branch_constraint_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    vars = create_array_of_vars(2, CL.MasterVar)

    constr = CL.generate_branch_constraint(alg, 2, vars[1], 'L', 2.5)
    @test constr.depth_when_generated == 2
    @test constr.cost_rhs == 2.5
    @test constr.sense == 'L'
    @test constr.member_coef_map[vars[1]] == 1.0
    @test vars[1].member_coef_map[constr] == 1.0

    constr = CL.generate_branch_constraint(alg, -3, vars[2], 'E', 98.0)
    @test constr.depth_when_generated == -3
    @test constr.cost_rhs == 98.0
    @test constr.sense == 'E'
    @test constr.member_coef_map[vars[2]] == 1.0
    @test vars[2].member_coef_map[constr] == 1.0
end

function generate_child_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    constrs = create_array_of_constrs(2, CL.BranchConstr)
    constrs = Vector{CL.BranchConstr}(constrs)
    CL.generate_child(alg, node, constrs)
    @test length(node.children) == 1
    @test length(node.children[1].local_branching_constraints) == 2
    @test node.children[1].local_branching_constraints[1] === constrs[1]
    @test node.children[1].local_branching_constraints[2] === constrs[2]
end

function perform_usual_branching_tests()
    extended_problem = create_extended_problem()
    alg = CL.UsualBranchingAlg(extended_problem)
    node = CL.Node(extended_problem, 0.0, CL.SetupInfo(), CL.EvalInfo())
    vars = create_array_of_vars(2, CL.MasterVar)
    var_val_map = [vars[1] => 1.0, vars[2] => 2.01]
    CL.perform_usual_branching(node, alg, var_val_map)
    @test length(node.children) == 2
    child_1 = node.children[1]
    @test length(child_1.local_branching_constraints) == 1
    @test child_1.local_branching_constraints[1].sense == 'G'
    @test child_1.local_branching_constraints[1].cost_rhs == 3.0
    @test haskey(child_1.local_branching_constraints[1].member_coef_map, vars[2])
    child_2 = node.children[2]
    @test length(child_2.local_branching_constraints) == 1
    @test child_2.local_branching_constraints[1].sense == 'L'
    @test child_2.local_branching_constraints[1].cost_rhs == 2.0
    @test haskey(child_2.local_branching_constraints[1].member_coef_map, vars[2])

end

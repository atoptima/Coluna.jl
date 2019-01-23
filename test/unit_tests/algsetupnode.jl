function algsetupnode_unit_tests()

    variable_small_info_tests()
    variable_info_tests()
    constraint_info_tests()
    problem_setup_info_tests()
    alg_to_setdown_node_tests()
    record_problem_info_tests()
    run_alg_to_setdown_node_tests
    alg_to_setup_node_tests()
    reset_partial_solution_tests()
    prepare_branching_constraints_added_by_father_tests()
    prepare_branching_constraints_tests()
    run_alg_setup_branching_only()
    find_first_in_problem_setup_tests()
    run_alg_setup_full_tests()
    update_formulation_tests()
    alg_to_setup_root_node_tests()
    run_alg_setup_root_node_tests()

end

function variable_small_info_tests()
    vars = create_array_of_vars(1, CL.Variable)
    var = vars[1]

    vsi = CL.VariableSmallInfo(var)
    @test vsi.variable === var
    @test vsi.cost == var.cur_cost_rhs
    @test vsi.status == CL.Active

    vsi = CL.VariableSmallInfo(var, CL.Unsuitable)
    @test vsi.variable === var
    @test vsi.cost == var.cur_cost_rhs
    @test vsi.status == CL.Unsuitable
end

function variable_info_tests()
    vars = create_array_of_vars(1, CL.Variable)
    var = vars[1]

    vinfo = CL.VariableInfo(var)
    @test vinfo.variable === var
    @test vinfo.lb == var.cur_lb
    @test vinfo.ub == var.cur_ub
    @test vinfo.status == CL.Active

    vinfo = CL.VariableInfo(var, CL.Inactive)
    @test vinfo.variable === var
    @test vinfo.lb == var.cur_lb
    @test vinfo.ub == var.cur_ub
    @test vinfo.status == CL.Inactive
end

function constraint_info_tests()
    vc_counter = CL.VarConstrCounter(0)
    constr = CL.Constraint(vc_counter, "C_1", 5.0, 'L', 'M', 's')

    cinfo = CL.ConstraintInfo(constr)
    @test cinfo.constraint === constr
    @test cinfo.min_slack == -Inf
    @test cinfo.max_slack == Inf
    @test cinfo.status == CL.Active

    cinfo = CL.ConstraintInfo(constr, CL.Unsuitable)
    @test cinfo.constraint === constr
    @test cinfo.min_slack == -Inf
    @test cinfo.max_slack == Inf
    @test cinfo.status == CL.Unsuitable
end

function problem_setup_info_tests()
    treat_order = 1
    psi = CL.ProblemSetupInfo(treat_order)
    @test psi.treat_order == treat_order
    @test psi.number_of_nodes == 0
    @test psi.full_setup_is_obligatory == false
    @test psi.suitable_master_columns_info == Vector{CL.VariableSmallInfo}()
    @test psi.suitable_master_cuts_info == Vector{CL.ConstraintInfo}()
    @test psi.active_branching_constraints_info == Vector{CL.ConstraintInfo}()
    @test psi.master_partial_solution_info == Vector{CL.VariableSolInfo}()
    @test psi.modified_static_vars_info == Vector{CL.VariableInfo}()
    @test psi.modified_static_constrs_info == Vector{CL.ConstraintInfo}()
end

function alg_to_setdown_node_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetdownNodeFully(extended_problem)
    @test alg.extended_problem === extended_problem
end

function run_alg_to_setdown_node_tests()
    extended_problem = create_extended_problem()
    
end

function record_problem_info_tests()
    extended_problem = create_extended_problem()
    counter = extended_problem.counter
    node = create_node(extended_problem, false)
    prob, vars, contrs = create_problem_knapsack(true, false, false)
    extended_problem.master_problem = prob
    master_problem = extended_problem.master_problem
    partial_solution = Dict{CL.Variable,Float64}(vars[1] => 1.0)
    master_problem.partial_solution = partial_solution

    # To test if adds correctly the static variables
    vars[1].cur_lb = vars[1].lower_bound
    vars[1].cur_ub = vars[1].upper_bound
    vars[1].cur_cost_rhs = vars[1].cost_rhs
    vars[2].cur_lb = vars[2].lower_bound - 0.1

    # To test if adds correctly the dynamic master variables
    sol = CL.PrimalSolution(0.0, Dict{CL.Variable,Float64}())
    mc = CL.MasterColumn(counter, sol)
    push!(master_problem.var_manager.active_dynamic_list, mc)

    # To test if adds correctly the dynamic constraints
    constr_1 = CL.MasterConstr(counter, "C", 5.0, 'L', 'M', 's')
    constr_2 = CL.BranchConstr(counter, "BC", 5.0, 'L', 3)
    constr_3 = CL.MasterConstr(counter, "C", 5.0, 'L', 'M', 's')
    constr_3.cur_min_slack = 2.0
    constr_4 = CL.MasterConstr(counter, "C", 5.0, 'L', 'M', 's')
    push!(master_problem.constr_manager.active_dynamic_list, constr_1)
    push!(master_problem.constr_manager.active_dynamic_list, constr_2)
    push!(master_problem.constr_manager.active_static_list, constr_3)
    push!(master_problem.constr_manager.active_static_list, constr_4)

    # To test if adds correctly the static (subproblem) variables
    subprob = create_problem_empty()
    sp_vars = create_array_of_vars(2, CL.SubprobVar)
    sp_vars[1].cur_lb = sp_vars[1].lower_bound
    sp_vars[1].cur_ub = sp_vars[1].upper_bound
    sp_vars[1].cur_global_lb = sp_vars[1].global_lb
    sp_vars[1].cur_global_ub = sp_vars[1].global_ub
    sp_vars[1].cur_cost_rhs = sp_vars[1].cost_rhs
    sp_vars[2].cur_global_lb = sp_vars[2].global_lb - 0.1
    push!(subprob.var_manager.active_static_list, sp_vars[1])
    push!(subprob.var_manager.active_static_list, sp_vars[2])
    push!(extended_problem.pricing_vect, subprob)

    alg = CL.AlgToSetdownNodeFully(extended_problem)
    CL.record_problem_info(alg, node)

    @test node.problem_setup_info.master_partial_solution_info[1].variable === vars[1]
    @test findfirst(x -> x.variable == vars[1], node.problem_setup_info.modified_static_vars_info) == nothing
    @test findfirst(x -> x.variable == vars[2], node.problem_setup_info.modified_static_vars_info) != nothing
    @test findfirst(x -> x.variable == mc, node.problem_setup_info.suitable_master_columns_info) != nothing
    @test findfirst(x -> x.constraint == constr_1, node.problem_setup_info.suitable_master_cuts_info) != nothing
    @test findfirst(x -> x.constraint == constr_2, node.problem_setup_info.active_branching_constraints_info) != nothing
    @test findfirst(x -> x.constraint == constr_3, node.problem_setup_info.modified_static_constrs_info) != nothing
    @test findfirst(x -> x.constraint == constr_4, node.problem_setup_info.modified_static_constrs_info) == nothing
    @test findfirst(x -> x.variable == sp_vars[1], node.problem_setup_info.modified_static_vars_info) == nothing
    @test findfirst(x -> x.variable == sp_vars[2], node.problem_setup_info.modified_static_vars_info) != nothing

end

function alg_to_setup_node_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetupNode(extended_problem)
    @test alg.extended_problem === extended_problem   
    @test alg.problem_setup_info.treat_order == 0
    @test alg.is_all_columns_active == false
    psi = CL.ProblemSetupInfo(0)
    alg = CL.AlgToSetupNode(extended_problem, psi)
    @test alg.extended_problem === extended_problem   
    @test alg.problem_setup_info === psi
    @test alg.is_all_columns_active == false
    alg = CL.AlgToSetupBranchingOnly(extended_problem)
    @test alg.extended_problem === extended_problem
    @test alg.problem_setup_info.treat_order == 0
    @test alg.is_all_columns_active == false
    alg = CL.AlgToSetupBranchingOnly(extended_problem, psi)
    @test alg.extended_problem === extended_problem   
    @test alg.problem_setup_info === psi
    @test alg.is_all_columns_active == false
    alg = CL.AlgToSetupFull(extended_problem, psi)
    @test alg.extended_problem === extended_problem   
    @test alg.problem_setup_info === psi
    @test alg.is_all_columns_active == false
end

function reset_partial_solution_tests()
    # This function does nothing, but is called
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetupBranchingOnly(extended_problem)
    CL.reset_partial_solution(alg)
end

function prepare_branching_constraints_added_by_father_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetupNode(extended_problem)
    node = create_node(extended_problem, false)
    constrs = create_array_of_constrs(2, CL.BranchConstr)
    node.local_branching_constraints = constrs
    CL.prepare_branching_constraints_added_by_father(alg, node)
    @test findfirst(x->x===constrs[1], extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x===constrs[2], extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
    @test length(extended_problem.master_problem.constr_manager.active_static_list) == 0
    @test length(extended_problem.master_problem.constr_manager.unsuitable_static_list) == 0
    @test length(extended_problem.master_problem.constr_manager.unsuitable_dynamic_list) == 0
end

function prepare_branching_constraints_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetupBranchingOnly(extended_problem)
    node = create_node(extended_problem, false)
    constrs = create_array_of_constrs(2, CL.BranchConstr)
    node.local_branching_constraints = constrs
    CL.prepare_branching_constraints(alg, node)
    @test findfirst(x->x===constrs[1], extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x===constrs[2], extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
    @test length(extended_problem.master_problem.constr_manager.active_static_list) == 0
    @test length(extended_problem.master_problem.constr_manager.unsuitable_static_list) == 0
    @test length(extended_problem.master_problem.constr_manager.unsuitable_dynamic_list) == 0

    prob, vars, constrs = create_problem_knapsack(true, false, true)
    prob.optimizer = nothing
    extended_problem.master_problem = prob
    counter = prob.counter
    node = create_node(extended_problem, false)
    bc1 = CL.BranchConstr(counter, "bc_1", 1.0, 'G', 3)
    bc2 = CL.BranchConstr(counter, "bc_2", 0.0, 'L', 3)
    bc3 = CL.BranchConstr(counter, "bc_3", 0.0, 'L', 3)
    bc4 = CL.BranchConstr(counter, "bc_3", 0.0, 'L', 3)
    push!(prob.constr_manager.active_dynamic_list, bc1)
    push!(prob.constr_manager.active_dynamic_list, bc2)
    push!(node.problem_setup_info.active_branching_constraints_info, CL.ConstraintInfo(bc1))
    push!(node.problem_setup_info.active_branching_constraints_info, CL.ConstraintInfo(bc3))
    push!(node.local_branching_constraints, bc4)

    psi = CL.ProblemSetupInfo(0)
    alg = CL.AlgToSetupFull(extended_problem, psi)
    CL.run(alg, node)

    @test length(prob.constr_manager.active_static_list) == 1
    @test findfirst(x->x===bc1, prob.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x===bc2, prob.constr_manager.active_dynamic_list) == nothing
    @test findfirst(x->x===bc3, prob.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x===bc4, extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
end

function run_alg_setup_branching_only()
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetupBranchingOnly(extended_problem)
    node = create_node(extended_problem, false)
    constrs = create_array_of_constrs(2, CL.BranchConstr)
    node.local_branching_constraints = constrs
    @test CL.run(alg, node) == false
    @test findfirst(x->x==constrs[1], extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x==constrs[2], extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
end

function find_first_in_problem_setup_tests()
    constrs = create_array_of_constrs(3, CL.BranchConstr)
    constr_info_vec = CL.ConstraintInfo[]
    vc_counter = CL.VarConstrCounter(0)
    for i in 1:length(constrs)
        CL.increment_counter(vc_counter)
        constrs[i].vc_ref = vc_counter.value
        push!(constr_info_vec, CL.ConstraintInfo(constrs[i]))
    end
    @test CL.find_first_in_problem_setup(constr_info_vec, 1) == 1
    @test CL.find_first_in_problem_setup(constr_info_vec, 5) == 0
end

function run_alg_setup_full_tests()
    extended_problem = create_extended_problem()
    prob, vars, constrs = create_problem_knapsack(true, false, true)
    prob.optimizer = nothing
    extended_problem.master_problem = prob
    counter = prob.counter
    node = create_node(extended_problem, false)
    bc1 = CL.BranchConstr(counter, "bc_1", 1.0, 'G', 3)
    bc2 = CL.BranchConstr(counter, "bc_2", 0.0, 'L', 3)
    bc3 = CL.BranchConstr(counter, "bc_3", 0.0, 'L', 3)
    bc4 = CL.BranchConstr(counter, "bc_3", 0.0, 'L', 3)
    push!(prob.constr_manager.active_dynamic_list, bc1)
    push!(prob.constr_manager.active_dynamic_list, bc2)
    push!(node.problem_setup_info.active_branching_constraints_info, CL.ConstraintInfo(bc1))
    push!(node.problem_setup_info.active_branching_constraints_info, CL.ConstraintInfo(bc3))
    push!(node.local_branching_constraints, bc4)

    psi = CL.ProblemSetupInfo(0)
    alg = CL.AlgToSetupFull(extended_problem, psi)
    CL.run(alg, node)

    @test length(prob.constr_manager.active_static_list) == 1
    @test findfirst(x->x==bc1, prob.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x==bc2, prob.constr_manager.active_dynamic_list) == nothing
    @test findfirst(x->x==bc3, prob.constr_manager.active_dynamic_list) != nothing
    @test findfirst(x->x==bc4, extended_problem.master_problem.constr_manager.active_dynamic_list) != nothing
end

function update_formulation_tests()
    # This function is empty
    extended_problem = create_extended_problem()
    alg = CL.AlgToSetupBranchingOnly(extended_problem)
    CL.update_formulation(alg)
    @test alg.extended_problem === extended_problem
end

function alg_to_setup_root_node_tests()
    extended_problem = create_extended_problem()
    psi = CL.ProblemSetupInfo(0)
    alg = CL.AlgToSetupRootNode(extended_problem, psi)
    @test alg.extended_problem === extended_problem   
    @test alg.problem_setup_info === psi
    @test alg.is_all_columns_active == false
end

function run_alg_setup_root_node_tests()
    # This function only calls another function that is empty
    extended_problem = create_extended_problem()
    psi = CL.ProblemSetupInfo(0)
    alg = CL.AlgToSetupRootNode(extended_problem, psi)
    node = create_node(extended_problem, false)
    @test CL.run(alg, node) == false
end

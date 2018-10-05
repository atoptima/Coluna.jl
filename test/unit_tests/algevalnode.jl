function alg_eval_node_unit_tests()

    update_primal_lp_bound_tests()
    update_primal_ip_incumbents_tests()
    update_primal_lp_incumbents_tests()
    update_dual_lp_bound_tests()
    update_dual_ip_bound_tests()
    update_dual_lp_incumbents_tests()
    alg_eval_node_tests()
    to_tests()
    update_alg_primal_lp_bound_tests()
    update_alg_primal_lp_incumbents_tests()
    update_alg_primal_ip_incumbents_tests()
    update_alg_dual_lp_bound_tests()
    update_alg_dual_lp_incumbents_tests()
    mark_infeasible_tests()
    setup_alg_eval_tests()    
    setdown_alg_eval_tests()
    alg_eval_node_by_lp_tests()
    run_alg_eval_node_by_lp_tests()
    alg_eval_lagrangian_duality_tests()
    cleanup_restricted_mast_columns_tests()
    update_alg_dual_lp_incumbents_tests()
    update_pricing_prob_tests()
    compute_pricing_dual_bound_contrib_tests()
    insert_cols_in_master_tests()
    gen_new_col_tests()
    gen_new_columns_tests()
    compute_mast_dual_bound_contrib_tests()
    update_lagrangian_dual_bound_tests()
    print_intermediate_statistics_tests()
    alg_to_eval_node_by_simplex_col_gen_tests()
    solve_restricted_mast_tests()
    solve_mast_lp_ph2_tests()
    run_alg_eval_node_by_simplex_col_gen_tests()

end

function update_primal_lp_bound_tests()
    incumbents = create_sols_and_bounds()
    incumbents.alg_inc_lp_primal_bound = 10.0
    CL.update_primal_lp_bound(incumbents, 9.0)
    @test incumbents.alg_inc_lp_primal_bound == 9.0
    CL.update_primal_lp_bound(incumbents, 9.0)
    @test incumbents.alg_inc_lp_primal_bound == 9.0
end

function update_primal_ip_incumbents_tests()
    incumbents = create_sols_and_bounds()
    incumbents.alg_inc_ip_primal_bound = 10.0
    vars = create_array_of_vars(3, CL.Variable)
    sol = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    CL.update_primal_ip_incumbents(incumbents, sol, 10.0)
    @test incumbents.is_alg_inc_ip_primal_bound_updated == false
    @test incumbents.alg_inc_ip_primal_bound == 10.0
    @test incumbents.alg_inc_ip_primal_sol_map == Dict{CL.Variable,Float64}()
    CL.update_primal_ip_incumbents(incumbents, sol, 9.0)
    @test incumbents.alg_inc_ip_primal_bound == 9.0
    @test incumbents.is_alg_inc_ip_primal_bound_updated == true
    @test haskey(incumbents.alg_inc_ip_primal_sol_map, vars[1])
    @test haskey(incumbents.alg_inc_ip_primal_sol_map, vars[2])
    @test !haskey(incumbents.alg_inc_lp_primal_sol_map, vars[3])
end

function update_primal_lp_incumbents_tests()
    incumbents = create_sols_and_bounds()
    incumbents.alg_inc_lp_primal_bound = 10.0
    vars = create_array_of_vars(3, CL.Variable)
    sol = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    CL.update_primal_lp_incumbents(incumbents, sol, 10.0)
    @test incumbents.alg_inc_lp_primal_sol_map == Dict{CL.Variable,Float64}()
    @test incumbents.alg_inc_lp_primal_bound == 10.0
    CL.update_primal_lp_incumbents(incumbents, sol, 9.0)
    @test incumbents.alg_inc_lp_primal_bound == 9.0
    @test haskey(incumbents.alg_inc_lp_primal_sol_map, vars[1])
    @test haskey(incumbents.alg_inc_lp_primal_sol_map, vars[2])
    @test !haskey(incumbents.alg_inc_lp_primal_sol_map, vars[3])
end

function update_dual_lp_bound_tests()
    incumbents = create_sols_and_bounds()
    incumbents.alg_inc_lp_dual_bound = 11.0
    vars = create_array_of_vars(3, CL.Variable)
    CL.update_dual_lp_bound(incumbents, 10.0)
    @test incumbents.alg_inc_lp_dual_bound == 11.0
    CL.update_dual_lp_bound(incumbents, 12.0)
    @test incumbents.alg_inc_lp_dual_bound == 12.0
end

function update_dual_ip_bound_tests()
    incumbents = create_sols_and_bounds()
    incumbents.alg_inc_ip_dual_bound = 11.0
    vars = create_array_of_vars(3, CL.Variable)
    CL.update_dual_ip_bound(incumbents, 10.0)
    @test incumbents.alg_inc_ip_dual_bound == 11.0
    CL.update_dual_ip_bound(incumbents, 12.0)
    @test incumbents.alg_inc_ip_dual_bound == 12.0
end

function update_dual_lp_incumbents_tests()
    incumbents = create_sols_and_bounds()
    incumbents.alg_inc_lp_dual_bound = 11.0
    constrs = create_array_of_constrs(3, CL.Constraint)
    sol = Dict{CL.Constraint,Float64}(constrs[1] => 1.0, constrs[2] => 2.0)
    CL.update_dual_lp_incumbents(incumbents, sol, 10.0)
    @test incumbents.alg_inc_lp_dual_sol_map == Dict{CL.Constraint,Float64}()
    @test incumbents.alg_inc_lp_dual_bound == 11.0
    CL.update_dual_lp_incumbents(incumbents, sol, 12.0)
    @test incumbents.alg_inc_lp_dual_bound == 12.0
    @test haskey(incumbents.alg_inc_lp_dual_sol_map, constrs[1])
    @test haskey(incumbents.alg_inc_lp_dual_sol_map, constrs[2])
    @test !haskey(incumbents.alg_inc_lp_dual_sol_map, constrs[3])
end

function alg_eval_node_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    @test alg.extended_problem === extended_problem
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == -Inf
    @test alg.sol_is_master_lp_feasible == false
    @test alg.is_master_converged == false
end

function to_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    timer_output = CL.to(alg)
    @test isa(timer_output, CL.TimerOutputs.TimerOutput)
end

function update_alg_primal_lp_bound_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_lp_primal_bound = 10.0

    vars = create_array_of_vars(3, CL.Variable)
    var_val_map = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    sol = CL.PrimalSolution(11.0, var_val_map)
    push!(extended_problem.master_problem.primal_sols, sol)
    CL.update_alg_primal_lp_bound(alg)
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == 10.0
    @test alg.sols_and_bounds.alg_inc_lp_primal_sol_map == Dict{CL.Variable,Float64}()
    sol = CL.PrimalSolution(9.0, var_val_map)
    push!(extended_problem.master_problem.primal_sols, sol)
    CL.update_alg_primal_lp_bound(alg)
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == 9.0
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_primal_sol_map, vars[1])
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_primal_sol_map, vars[2])
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_primal_sol_map, vars[3])
end

function update_alg_primal_lp_incumbents_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_lp_primal_bound = 10.0

    vars = create_array_of_vars(3, CL.Variable)
    var_val_map = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    sol = CL.PrimalSolution(11.0, var_val_map)
    push!(extended_problem.master_problem.primal_sols, sol)
    CL.update_alg_primal_lp_incumbents(alg)
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == 10.0
    @test alg.sols_and_bounds.alg_inc_lp_primal_sol_map == Dict{CL.Variable,Float64}()
    sol = CL.PrimalSolution(9.0, var_val_map)
    push!(extended_problem.master_problem.primal_sols, sol)
    CL.update_alg_primal_lp_incumbents(alg)
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == 9.0
    @test haskey(alg.sols_and_bounds.alg_inc_lp_primal_sol_map, vars[1])
    @test haskey(alg.sols_and_bounds.alg_inc_lp_primal_sol_map, vars[2])
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_primal_sol_map, vars[3])
end

function update_alg_primal_ip_incumbents_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_ip_primal_bound = 10.0

    vars = create_array_of_vars(3, CL.Variable)
    var_val_map = Dict{CL.Variable,Float64}(vars[1] => 1.0, vars[2] => 2.0)
    sol = CL.PrimalSolution(11.0, var_val_map)
    push!(extended_problem.master_problem.primal_sols, sol)
    CL.update_alg_primal_ip_incumbents(alg)
    @test alg.sols_and_bounds.alg_inc_ip_primal_bound == 10.0
    @test alg.sols_and_bounds.alg_inc_ip_primal_sol_map == Dict{CL.Variable,Float64}()
    sol = CL.PrimalSolution(9.0, var_val_map)
    push!(extended_problem.master_problem.primal_sols, sol)
    CL.update_alg_primal_ip_incumbents(alg)
    @test alg.sols_and_bounds.alg_inc_ip_primal_bound == 9.0
    @test haskey(alg.sols_and_bounds.alg_inc_ip_primal_sol_map, vars[1])
    @test haskey(alg.sols_and_bounds.alg_inc_ip_primal_sol_map, vars[2])
    @test !haskey(alg.sols_and_bounds.alg_inc_ip_primal_sol_map, vars[3])
end

function update_alg_dual_lp_bound_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_lp_dual_bound = 10.0

    constrs = create_array_of_constrs(3, CL.Constraint)
    constr_val_map = Dict{CL.Constraint,Float64}(constrs[1] => 1.0, constrs[2] => 2.0)
    sol = CL.DualSolution(9.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, sol)
    CL.update_alg_dual_lp_bound(alg)
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == 10.0
    @test alg.sols_and_bounds.alg_inc_lp_dual_sol_map == Dict{CL.Constraint,Float64}()
    sol = CL.DualSolution(11.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, sol)
    CL.update_alg_dual_lp_bound(alg)
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == 11.0
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_dual_sol_map, constrs[1])
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_dual_sol_map, constrs[2])
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_dual_sol_map, constrs[3])
end

function update_alg_dual_lp_incumbents_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_lp_dual_bound = 10.0

    constrs = create_array_of_constrs(3, CL.Constraint)
    constr_val_map = Dict{CL.Constraint,Float64}(constrs[1] => 1.0, constrs[2] => 2.0)
    sol = CL.DualSolution(9.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, sol)
    CL.update_alg_dual_lp_incumbents(alg)
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == 10.0
    @test alg.sols_and_bounds.alg_inc_lp_dual_sol_map == Dict{CL.Constraint,Float64}()
    sol = CL.DualSolution(11.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, sol)
    CL.update_alg_dual_lp_incumbents(alg)
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == 11.0
    @test haskey(alg.sols_and_bounds.alg_inc_lp_dual_sol_map, constrs[1])
    @test haskey(alg.sols_and_bounds.alg_inc_lp_dual_sol_map, constrs[2])
    @test !haskey(alg.sols_and_bounds.alg_inc_lp_dual_sol_map, constrs[3])
end

function update_alg_dual_ip_bound_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_ip_dual_bound = 10.0

    constrs = create_array_of_constrs(3, CL.Constraint)
    constr_val_map = Dict{CL.Constraint,Float64}(constrs[1] => 1.0, constrs[2] => 2.0)
    sol = CL.DualSolution(9.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, sol)
    CL.update_alg_dual_ip_bound(alg)
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == 10.0
    @test alg.sols_and_bounds.alg_inc_ip_dual_sol_map == Dict{CL.Constraint,Float64}()
    sol = CL.DualSolution(11.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, sol)
    CL.update_alg_dual_ip_bound(alg)
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == 11.0
    @test !haskey(alg.sols_and_bounds.alg_inc_ip_dual_sol_map, constrs[1])
    @test !haskey(alg.sols_and_bounds.alg_inc_ip_dual_sol_map, constrs[2])
    @test !haskey(alg.sols_and_bounds.alg_inc_ip_dual_sol_map, constrs[3])
end

function mark_infeasible_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    alg.sols_and_bounds.alg_inc_ip_primal_bound = -67.0
    alg.sols_and_bounds.alg_inc_lp_primal_bound = -1.0
    alg.sols_and_bounds.alg_inc_ip_dual_bound = 100.3
    alg.sols_and_bounds.alg_inc_lp_dual_bound = 20.3
    alg.sol_is_master_lp_feasible = true
    CL.mark_infeasible(alg)
    @test alg.sols_and_bounds.alg_inc_ip_primal_bound == -67.0
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == Inf
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == Inf
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == Inf
    @test alg.sol_is_master_lp_feasible == false
end

function setup_alg_eval_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    @test CL.setup(alg) == false
end

function setdown_alg_eval_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNode(extended_problem)
    @test CL.setdown(alg) == false
end

function alg_eval_node_by_lp_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNodeByLp(extended_problem)
    @test alg.extended_problem === extended_problem
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == -Inf
    @test alg.sol_is_master_lp_feasible == false
    @test alg.is_master_converged == false
end

function run_alg_eval_node_by_lp_tests()
    extended_problem = create_extended_problem()

    # Test when solution is fractional
    prob, vars, constrs = create_problem_knapsack(true, false, true)
    extended_problem.master_problem = prob
    for i in 1:length(vars)
        vars[i].vc_type = 'I'
    end
    alg = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.run(alg) == false
    @test alg.sol_is_master_lp_feasible == true
    @test length(prob.primal_sols) == 2
    @test prob.primal_sols[end].cost ≈ -11.66666666 atol = rtol = 0.000001
    @test !haskey(prob.primal_sols[end].var_val_map, vars[1])
    @test haskey(prob.primal_sols[end].var_val_map, vars[2])
    @test !haskey(prob.primal_sols[end].var_val_map, vars[3])
    @test !haskey(prob.primal_sols[end].var_val_map, vars[4])
    @test !haskey(prob.primal_sols[end].var_val_map, vars[5])
    @test alg.sols_and_bounds.alg_inc_ip_primal_bound == Inf
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == prob.primal_sols[end].cost
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == -Inf
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == -Inf
    @test alg.sol_is_master_lp_feasible == true

    # Test when solution is integer
    prob, vars, constrs = create_problem_knapsack(true, true, false)
    extended_problem.master_problem = prob
    alg = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.run(alg) == false
    @test alg.sol_is_master_lp_feasible == true
    @test length(prob.primal_sols) == 2
    @test prob.primal_sols[end].cost == -11.0
    @test !haskey(prob.primal_sols[end].var_val_map, vars[1])
    @test haskey(prob.primal_sols[end].var_val_map, vars[2])
    @test !haskey(prob.primal_sols[end].var_val_map, vars[3])
    @test haskey(prob.primal_sols[end].var_val_map, vars[4])
    @test !haskey(prob.primal_sols[end].var_val_map, vars[5])
    @test alg.sols_and_bounds.alg_inc_ip_primal_bound == -11.0
    @test alg.sols_and_bounds.alg_inc_lp_primal_bound == prob.primal_sols[end].cost
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == -Inf
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == -Inf
    @test alg.sol_is_master_lp_feasible == true


    # Testing for an infeasible problem
    prob, vars, constrs = create_problem_knapsack(false, false, true)
    extended_problem.master_problem = prob
    alg = CL.AlgToEvalNodeByLp(extended_problem)
    @test CL.run(alg) == true
    @test alg.sol_is_master_lp_feasible == false
end

function alg_eval_lagrangian_duality_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    @test alg.pricing_contribs == Dict{CL.Problem, Float64}()
    @test alg.pricing_const_obj == Dict{CL.Problem, Float64}()
    @test alg.colgen_stabilization == nothing
    @test alg.max_nb_cg_iterations == 10000
end

function cleanup_restricted_mast_columns_tests()
    # This function is empty
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    CL.cleanup_restricted_mast_columns(alg, 1)
end

function update_pricing_target_tests()
    # This function is empty
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    prob, vars, constrs = create_problem_knapsack(false, false, true)
    CL.update_pricing_target(alg, prob)
end

function update_pricing_prob_tests()
    extended_problem = create_cg_extended_problem()
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    constrs = extended_problem.master_problem.constr_manager.active_static_list
    constr_val_map = Dict{CL.Constraint,Float64}()
    for i in 1:length(constrs)
        constr_val_map[constrs[i]] = 3.3 * i
    end
    dual_sol = CL.DualSolution(-1.0, constr_val_map)
    push!(extended_problem.master_problem.dual_sols, dual_sol)
    pricing = extended_problem.pricing_vect[1]
    @test CL.update_pricing_prob(alg, pricing) == false
    moi_obj = MOI.get(pricing.optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    terms = moi_obj.terms
    vars = pricing.var_manager.active_static_list
    expected_obj_with_strings = Dict{String,Float64}("x2"=>-13.2,"y"=>1.0,"x1"=>-9.9,"x3"=>-16.5)
    for i in 1:length(vars)
        idx_in_terms = findfirst(x->x.variable_index==vars[i].moi_index, terms)
        term = terms[idx_in_terms]
        @test idx_in_terms != nothing
        idx_in_vars = findfirst(x->x.moi_index == term.variable_index, vars)
        @test idx_in_vars != nothing
        var_name = vars[idx_in_vars].name
        @test expected_obj_with_strings[var_name] ≈ term.coefficient atol = rtol = 0.000001
    end    
end

function compute_pricing_dual_bound_contrib_tests()
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    alg.pricing_const_obj[pricing] = -13.0
    pricing.obj_val = 10.0
    CL.compute_pricing_dual_bound_contrib(alg, pricing)
    @test alg.pricing_contribs[pricing] == -3.0
end

function insert_cols_in_master_tests()
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    primal_sol = CL.PrimalSolution(1.0, Dict{CL.Variable,Float64}())
    push!(pricing.primal_sols, primal_sol)
    @test CL.insert_cols_in_master(alg, pricing) == 0
    primal_sol = CL.PrimalSolution(-1.0, Dict{CL.Variable,Float64}())
    push!(pricing.primal_sols, primal_sol)
    @test CL.insert_cols_in_master(alg, pricing) == 1
    dynamic_list = extended_problem.master_problem.var_manager.active_dynamic_list
    @test length(dynamic_list) == 1
    @test findfirst(x->isa(x, CL.MasterColumn), dynamic_list) != nothing
    col = dynamic_list[1]
    convexity_lb = extended_problem.pricing_convexity_lbs[pricing]
    convexity_ub = extended_problem.pricing_convexity_ubs[pricing]
    @test col.member_coef_map[convexity_ub] == 1.0
    @test col.member_coef_map[convexity_lb] == 1.0
    @test convexity_lb.member_coef_map[col] == 1.0
    @test convexity_ub.member_coef_map[col] == 1.0
end

function gen_new_col_tests()
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)

    # Test when there is no column to insert
    @test CL.gen_new_col(alg, pricing) == 0
    @test length(extended_problem.master_problem.var_manager.active_dynamic_list) == 0

    # TODO: Test when there is column to add

    # Test when pricing is infeasible
    infeas_constr = CL.Constraint(pricing.counter, "infeas", -1.0, 'L', 'C', 's')
    CL.add_constraint(pricing, infeas_constr)
    var = pricing.var_manager.active_static_list[1]
    CL.add_membership(pricing, var, infeas_constr, 1.0)
    @test CL.gen_new_col(alg, pricing) == -1
end

function gen_new_columns_tests()
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)

    # Test when there is no column to insert
    @test CL.gen_new_columns(alg) == 0
    @test length(extended_problem.master_problem.var_manager.active_dynamic_list) == 0

    # Test when pricing is infeasible
    infeas_constr = CL.Constraint(pricing.counter, "infeas", -1.0, 'L', 'C', 's')
    CL.add_constraint(pricing, infeas_constr)
    var = pricing.var_manager.active_static_list[1]
    CL.add_membership(pricing, var, infeas_constr, 1.0)
    @test CL.gen_new_columns(alg) == -1
end

function compute_mast_dual_bound_contrib_tests()
    extended_problem = create_cg_extended_problem()
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    primal_sol = CL.PrimalSolution(-13.4, Dict{CL.Variable,Float64}())
    push!(extended_problem.master_problem.primal_sols, primal_sol)
    @test CL.compute_mast_dual_bound_contrib(alg) == -13.4

    # Test with stabilization != nothing
    alg.colgen_stabilization = CL.ColGenStabilization()
    try CL.compute_mast_dual_bound_contrib(alg)
        error("Test error: Stabilization is not empty and an error was not produced inside Coluna.")
    catch err
        @test err == ErrorException("compute_mast_dual_bound_contrib" *
                                    "is not yet implemented with stabilization")
    end
end

function update_lagrangian_dual_bound_tests()
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    primal_sol = CL.PrimalSolution(-13.4, Dict{CL.Variable,Float64}())
    push!(extended_problem.master_problem.primal_sols, primal_sol)
    alg.pricing_contribs[pricing] = -10.2
    CL.update_lagrangian_dual_bound(alg, true)
    @test alg.sols_and_bounds.alg_inc_lp_dual_bound == -23.6
    @test alg.sols_and_bounds.alg_inc_ip_dual_bound == -23.6

    # Test with stabilization != nothing
    alg.colgen_stabilization = CL.ColGenStabilization()
    try CL.update_lagrangian_dual_bound(alg, true)
        error("Test error: Stabilization is not empty and an error was not produced inside Coluna.")
    catch err
        @test err == ErrorException("compute_mast_dual_bound_contrib" *
                                    "is not yet implemented with stabilization")
    end
end

function print_intermediate_statistics_tests()
    # It gives me the following error:
    # ERROR: LoadError: IOError: write: broken pipe (EPIPE)

    # extended_problem = create_extended_problem()
    # alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    # alg.sols_and_bounds.alg_inc_lp_primal_bound = 2
    # alg.sols_and_bounds.alg_inc_lp_dual_bound = 4
    # alg.sols_and_bounds.alg_inc_ip_dual_bound = 8
    # alg.sols_and_bounds.alg_inc_ip_primal_bound = 64
    # backup_stdout = stdout
    # (rd, wr) = redirect_stdout()
    # CL.print_intermediate_statistics_tests(alg, -32, -64)
    # close(wr)
    # s = String(readavailable(rd))
    # close(rd)
    # redirect_stdout(backup_stdout)
    # @test s == "<it=-64> <cols=-32> <mlp=2> <DB=4> <PB=64>"
end

function alg_to_eval_node_by_simplex_col_gen_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    @test alg.pricing_contribs == Dict{CL.Problem, Float64}()
    @test alg.pricing_const_obj == Dict{CL.Problem, Float64}()
    @test alg.colgen_stabilization == nothing
    @test alg.max_nb_cg_iterations == 10000
end

function solve_restricted_mast_tests()
    extended_problem = create_cg_extended_problem()
    alg = CL.AlgToEvalNodeByLagrangianDuality(extended_problem)
    @test CL.solve_restricted_mast(alg) == MOI.Success
end

function solve_mast_lp_ph2_tests()
    # Standard case where everything goes well
    extended_problem = create_cg_extended_problem()
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg.sol_is_master_lp_feasible = true
    @test CL.solve_mast_lp_ph2(alg) == false
    sols_and_bounds = alg.sols_and_bounds
    @test sols_and_bounds.alg_inc_ip_primal_bound == 2.0
    @test sols_and_bounds.alg_inc_lp_primal_bound == 2.0
    @test sols_and_bounds.alg_inc_ip_dual_bound == 2.0
    @test sols_and_bounds.alg_inc_lp_dual_bound == 2.0
    @test alg.is_master_converged == true

    # Limit of cg_iterations
    extended_problem = create_cg_extended_problem()
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg.sol_is_master_lp_feasible = true
    alg.max_nb_cg_iterations = 1
    @test CL.solve_mast_lp_ph2(alg) == true
    sols_and_bounds = alg.sols_and_bounds
    @test sols_and_bounds.alg_inc_lp_primal_bound == Inf
    @test sols_and_bounds.alg_inc_ip_dual_bound == Inf
    @test sols_and_bounds.alg_inc_lp_dual_bound == Inf
    @test alg.sol_is_master_lp_feasible == false
    @test alg.is_master_converged == false
    
    # Test when pricing is infeasible
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg.sol_is_master_lp_feasible = true
    infeas_constr = CL.Constraint(pricing.counter, "infeas", -1.0, 'L', 'C', 's')
    CL.add_constraint(pricing, infeas_constr)
    var = pricing.var_manager.active_static_list[1]
    CL.add_membership(pricing, var, infeas_constr, 1.0)
    @test CL.solve_mast_lp_ph2(alg) == true
    sols_and_bounds = alg.sols_and_bounds
    @test sols_and_bounds.alg_inc_lp_primal_bound == Inf
    @test sols_and_bounds.alg_inc_ip_dual_bound == Inf
    @test sols_and_bounds.alg_inc_lp_dual_bound == Inf
    @test alg.sol_is_master_lp_feasible == false
    @test alg.is_master_converged == false

    # Test when master is infeasible
    extended_problem = create_cg_extended_problem()
    master = extended_problem.master_problem
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg.sol_is_master_lp_feasible = true
    infeas_constr = CL.Constraint(master.counter, "infeas", -1.0, 'L', 'C', 's')
    CL.add_constraint(master, infeas_constr)
    var = extended_problem.artificial_global_pos_var
    CL.add_membership(master, var, infeas_constr, 1.0)
    @test CL.solve_mast_lp_ph2(alg) == true
    sols_and_bounds = alg.sols_and_bounds
    @test sols_and_bounds.alg_inc_lp_primal_bound == Inf
    @test sols_and_bounds.alg_inc_ip_dual_bound == Inf
    @test sols_and_bounds.alg_inc_lp_dual_bound == Inf
    @test alg.sol_is_master_lp_feasible == false
    @test alg.is_master_converged == false
end

function run_alg_eval_node_by_simplex_col_gen_tests()
    # Standard case where everything goes well
    extended_problem = create_cg_extended_problem()
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg.sol_is_master_lp_feasible = false
    @test CL.run(alg) == false
    sols_and_bounds = alg.sols_and_bounds
    @test sols_and_bounds.alg_inc_ip_primal_bound == 2.0
    @test sols_and_bounds.alg_inc_lp_primal_bound == 2.0
    @test sols_and_bounds.alg_inc_ip_dual_bound == 2.0
    @test sols_and_bounds.alg_inc_lp_dual_bound == 2.0
    @test alg.is_master_converged == true
    @test alg.sol_is_master_lp_feasible == true

    # Test when pricing is infeasible
    extended_problem = create_cg_extended_problem()
    pricing = extended_problem.pricing_vect[1]
    alg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg.sol_is_master_lp_feasible = true
    infeas_constr = CL.Constraint(pricing.counter, "infeas", -1.0, 'L', 'C', 's')
    CL.add_constraint(pricing, infeas_constr)
    var = pricing.var_manager.active_static_list[1]
    CL.add_membership(pricing, var, infeas_constr, 1.0)
    @test CL.run(alg) == false
    sols_and_bounds = alg.sols_and_bounds
    @test sols_and_bounds.alg_inc_lp_primal_bound == Inf
    @test sols_and_bounds.alg_inc_ip_dual_bound == Inf
    @test sols_and_bounds.alg_inc_lp_dual_bound == Inf
    @test alg.sol_is_master_lp_feasible == false
    @test alg.is_master_converged == false
end

function problem_unit_tests()

    clear_tests()
    add_var_in_manager_tests()
    add_and_remove_constr_in_manager_tests()
    problem_counter_tests()
    initialize_problem_optimizer_tests()
    set_optimizer_obj_tests()
    fill_primal_sol_tests()
    retrieve_primal_sol_tests()
    retrieve_dual_sol_tests()
    is_sol_integer_tests()
    add_variable_tests()
    add_variable_in_optimizer_tests()
    add_constraint_tests()
    add_constr_in_optimizer_tests()
    delete_constraint_tests()
    add_membership_tests()
    optimize!_tests()
    optimize_tests()
    extended_problem_tests()
    initialize_extended_problem_optimizer_tests()
    add_convexity_constraints_tests()
    add_artificial_variables_tests()
    get_problem_tests()

end

function clear_tests()
    basis = CL.LpBasisRecord("basis_1")
    vars_vec = create_array_of_vars(10, CL.Variable)
    vars = [CL.VarMpFormStatus(vars_vec[i], 1) for i in 1:10]
    constrs_vec = create_array_of_constrs(10, CL.Constraint)
    constrs = [CL.ConstrMpFormStatus(constrs_vec[i], 1) for i in 1:10]
    basis.vars_in_basis = vars
    basis.constr_in_basis = constrs
    CL.clear(basis)
    @test length(basis.vars_in_basis) == 0
    @test length(basis.constr_in_basis) == 0
end

function add_var_in_manager_tests()
    vc_counter = CL.VarConstrCounter(0)
    v1 = CL.Variable(vc_counter, "var_1", 1.0, 'P', 'B',
                     's', 'U', 2.0, 0.0, 1.0)
    v2 = CL.Variable(vc_counter, "var_2", 1.0, 'P', 'B',
                     's', 'U', 2.0, 0.0, 1.0); v2.status = CL.Unsuitable
    v3 = CL.Variable(vc_counter, "var_3", 1.0, 'P', 'B',
                     'd', 'U', 2.0, 0.0, 1.0)
    v4 = CL.Variable(vc_counter, "var_4", 1.0, 'P', 'B',
                     'd', 'U', 2.0, 0.0, 1.0); v4.status = CL.Unsuitable
    v5 = CL.Variable(vc_counter, "var_5", 1.0, 'P', 'B',
                     'z', 'U', 2.0, 0.0, 1.0)

    var_manager = CL.SimpleVarIndexManager()
    CL.add_var_in_manager(var_manager, v1)
    CL.add_var_in_manager(var_manager, v2)
    CL.add_var_in_manager(var_manager, v3)
    CL.add_var_in_manager(var_manager, v4)
    @test var_manager.active_static_list[1] == v1
    @test var_manager.active_dynamic_list[1] == v3
    @test var_manager.unsuitable_static_list[1] == v2
    @test var_manager.unsuitable_dynamic_list[1] == v4
    try CL.add_var_in_manager(var_manager, v5)
        error("Test error: Status Active and flag z are not supported, but Coluna did not throw error.")
    catch err
        @test err == ErrorException("Status Active and flag z are not supported")
    end

end

function add_and_remove_constr_in_manager_tests()
    vc_counter = CL.VarConstrCounter(0)
    constr_1 = CL.Constraint(vc_counter, "C_1", 5.0, 'L', 'M', 's')
    constr_2 = CL.Constraint(vc_counter, "C_2", 5.0, 'L', 'M', 's')
    constr_2.status = CL.Unsuitable
    constr_3 = CL.Constraint(vc_counter, "C_3", 5.0, 'L', 'M', 'd')
    constr_4 = CL.Constraint(vc_counter, "C_4", 5.0, 'L', 'M', 'd')
    constr_4.status = CL.Unsuitable
    constr_5 = CL.Constraint(vc_counter, "C_5", 5.0, 'L', 'M', 'z')
    constr_manager = CL.SimpleConstrIndexManager()
    CL.add_constr_in_manager(constr_manager, constr_1)
    CL.add_constr_in_manager(constr_manager, constr_2)
    CL.add_constr_in_manager(constr_manager, constr_3)
    CL.add_constr_in_manager(constr_manager, constr_4)
    # Test if added correctly
    @test constr_manager.active_static_list[1] == constr_1
    @test constr_manager.active_dynamic_list[1] == constr_3
    @test constr_manager.unsuitable_static_list[1] == constr_2
    @test constr_manager.unsuitable_dynamic_list[1] == constr_4
    try CL.add_constr_in_manager(constr_manager, constr_5)
        error("Test error: Status Active and flag z are not supported, but Coluna did not throw error.")
    catch err
        @test err == ErrorException("Status Active and flag z are not supported")
    end

    # Test removing
    CL.remove_from_constr_manager(constr_manager, constr_1)
    @test length(constr_manager.active_static_list) == 0
    CL.remove_from_constr_manager(constr_manager, constr_2)
    @test length(constr_manager.unsuitable_static_list) == 0
    CL.remove_from_constr_manager(constr_manager, constr_3)
    @test length(constr_manager.active_dynamic_list) == 0
    CL.remove_from_constr_manager(constr_manager, constr_4)
    @test length(constr_manager.unsuitable_dynamic_list) == 0
    try CL.remove_from_constr_manager(constr_manager, constr_5)
        error("Test error: Status Active and flag z are not supported, but Coluna did not throw error.")
    catch err
        @test err == ErrorException("Status Active and flag z are not supported")
    end
end

function problem_counter_tests()
    prob_counter = CL.ProblemCounter(0)
    @test CL.increment_counter(prob_counter) == 1
    @test prob_counter.value == 1
end

function initialize_problem_optimizer_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    @test problem.optimizer == nothing
    CL.initialize_problem_optimizer(problem, optimizer)
    @test isa(problem.optimizer,  MOIU.CachingOptimizer)
    @test MOI.get(problem.optimizer, MOI.ObjectiveSense()) == MOI.MIN_SENSE
end

function set_optimizer_obj_tests()
    problem, vars, constr = create_problem_knapsack()
    obj = Dict{CL.Variable, Float64}()
    for i in 1:length(vars)
        obj[vars[i]] = vars[i].cost_rhs
    end
    CL.set_optimizer_obj(problem, obj)
    obj_from_coluna = MOI.get(problem.optimizer,
       MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    @test 5 == length(obj_from_coluna.terms)
end

function fill_primal_sol_tests()
    problem, vars, constr = create_problem_knapsack()
    MOI.optimize!(problem.optimizer)
    sol = Dict{CL.Variable,Float64}()
    CL.fill_primal_sol(problem, sol, problem.var_manager.active_static_list,
                       problem.optimizer, true)
    @test sol[vars[4]] == 1.0
    @test sol[vars[2]] == 1.0
    @test length(sol) == 2
end

function retrieve_primal_sol_tests()
    problem = create_problem_empty()
    try CL.retrieve_primal_sol(problem)
        error("Test error: Problem has no optimizer, bu Coluna did not throw error.")
    catch err
        @test err == ErrorException("The problem has no optimizer attached")
    end
    problem, vars, constr = create_problem_knapsack()
    MOI.optimize!(problem.optimizer)
    CL.retrieve_primal_sol(problem)
    sol = problem.primal_sols[end].var_val_map
    @test sol[vars[4]] == 1.0
    @test sol[vars[2]] == 1.0
    @test length(sol) == 2
end

function retrieve_dual_sol_tests()
    ## Not working properly
    problem = create_problem_empty()
    try CL.retrieve_dual_sol(problem)
        error("Test error: Problem has no optimizer, bu Coluna did not throw error.")
    catch err
        @test err == ErrorException("The problem has no optimizer attached")
    end
    problem, vars, constr = create_problem_knapsack()
    MOI.optimize!(problem.optimizer)
    CL.retrieve_dual_sol(problem)
    sol = problem.dual_sols[end].constr_val_map
    # @test sol[constr] == 7.0
end

function is_sol_integer_tests()
    tol = 0.0000001
    vars = create_array_of_vars(4, CL.Variable)
    vars[1].vc_type = 'C'

    vals_1 = [0.5, 1.0, -1.0, 30.00000001]
    sol_1 = Dict{CL.Variable,Float64}()
    for i in 1:length(vals_1)
        sol_1[vars[i]] = vals_1[i]
    end
    @test CL.is_sol_integer(sol_1, tol) == true

    vals_2 = [0.5, 1.0, -1.0, 30.000001]
    sol_2 = Dict{CL.Variable,Float64}()
    for i in 1:length(vals_2)
        sol_2[vars[i]] = vals_2[i]
    end
    @test CL.is_sol_integer(sol_2, tol) == false
    sol_2[vars[4]] = 30.0
    vars[1].vc_type = 'B'
    @test CL.is_sol_integer(sol_2, tol) == false
end

function add_variable_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    vars = create_array_of_vars(4, CL.Variable)

    vars[1].vc_type = 'B'
    vars[1].upper_bound = 1.0
    vars[1].lb = 0.0
    CL.add_variable(problem, vars[1])
    objf = MOI.get(problem.optimizer,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    @test length(objf.terms) == 1
    @test objf.terms[1].coefficient == vars[1].cost_rhs
    @test objf.terms[1].variable_index == vars[1].moi_index
    list_of_ci = MOI.get(problem.optimizer, MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.ZeroOne}())
    @test length(list_of_ci) == 1
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[1]) == MOI.SingleVariable(vars[1].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[1]) == MOI.ZeroOne()
    @test findfirst(x->x===vars[1], problem.var_manager.active_static_list) != nothing
    @test length(problem.var_manager.active_static_list) == 1
    @test length(problem.var_manager.active_dynamic_list) == 0
    @test length(problem.var_manager.unsuitable_static_list) == 0
    @test length(problem.var_manager.unsuitable_dynamic_list) == 0
    @test vars[1].prob_ref == problem.prob_ref

    problem = create_problem_empty()
    vars = create_array_of_vars(1, CL.SubprobVar)
    constr = create_array_of_constrs(1, CL.MasterConstr)
    vc_counter = CL.VarConstrCounter(2)
    sol = CL.PrimalSolution(0.0, Dict{CL.Variable,Float64}())
    vals = [0.5]
    for i in 1:length(vals)
        CL.add_membership(problem, vars[i], constr[1], 1.0)
        sol.var_val_map[vars[i]] = vals[i]
    end
    mc = CL.MasterColumn(vc_counter, sol)
    CL.add_variable(problem, mc)
    @test mc.member_coef_map[constr[1]] == 0.5
    @test constr[1].member_coef_map[mc] == 0.5
    @test findfirst(x->x===mc, problem.var_manager.active_dynamic_list) != nothing
    @test length(problem.var_manager.active_static_list) == 0
    @test length(problem.var_manager.active_dynamic_list) == 1
    @test length(problem.var_manager.unsuitable_static_list) == 0
    @test length(problem.var_manager.unsuitable_dynamic_list) == 0
    @test mc.prob_ref == problem.prob_ref
end

function add_variable_in_optimizer_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    vars = create_array_of_vars(4, CL.Variable)

    vars[1].vc_type = 'B'
    vars[1].upper_bound = 1.0
    vars[1].lb = 0.0
    CL.add_variable_in_optimizer(problem.optimizer, vars[1], false)
    objf = MOI.get(problem.optimizer,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    @test length(objf.terms) == 1
    @test objf.terms[1].coefficient == vars[1].cost_rhs
    @test objf.terms[1].variable_index == vars[1].moi_index
    list_of_ci = MOI.get(problem.optimizer, MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.ZeroOne}())
    @test length(list_of_ci) == 1
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[1]) == MOI.SingleVariable(vars[1].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[1]) == MOI.ZeroOne()

    vars[2].vc_type = 'B'
    vars[2].upper_bound = 1.0
    vars[2].lb = 0.1
    CL.add_variable_in_optimizer(problem.optimizer, vars[2], false)
    objf = MOI.get(problem.optimizer,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    @test length(objf.terms) == 2
    @test objf.terms[2].coefficient == vars[2].cost_rhs
    @test objf.terms[2].variable_index == vars[2].moi_index
    list_of_ci = MOI.get(problem.optimizer,
    MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.Interval{Float64}}())
    @test length(list_of_ci) == 0

    vars[3].vc_type = 'I'
    CL.add_variable_in_optimizer(problem.optimizer, vars[3], false)
    list_of_ci = MOI.get(problem.optimizer,
    MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.Integer}())
    @test length(list_of_ci) == 1
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[1]) == MOI.SingleVariable(vars[3].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[1]) == MOI.Integer()

    vars[4].vc_type = 'C'
    vars[4].lb = 5.0
    vars[4].upper_bound = 10.0
    CL.add_variable_in_optimizer(problem.optimizer, vars[4], false)
    list_of_ci = MOI.get(problem.optimizer,
    MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.Interval{Float64}}())
    @test length(list_of_ci) == 2
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[2]) == MOI.SingleVariable(vars[4].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[2]) == MOI.Interval{Float64}(vars[4].lower_bound,vars[4].upper_bound)
end

function add_constraint_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    constrs = create_array_of_constrs(1, CL.MasterConstr)
    constr = constrs[1]
    CL.add_constraint(problem, constr)
    @test constr.moi_index == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(1)
    @test findfirst(x->x===constr, problem.constr_manager.active_static_list) != nothing
    @test length(problem.constr_manager.active_static_list) == 1
    @test length(problem.constr_manager.active_dynamic_list) == 0
    @test length(problem.constr_manager.unsuitable_static_list) == 0
    @test length(problem.constr_manager.unsuitable_dynamic_list) == 0
    @test constr.prob_ref == problem.prob_ref
end

function add_constr_in_optimizer_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    constrs = create_array_of_constrs(1, CL.MasterBranchConstr)
    constr = constrs[1]
    CL.add_constr_in_optimizer(problem.optimizer, constr)
    list_of_ci = MOI.get(problem.optimizer, MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}())
    @test length(list_of_ci) == 1
    @test list_of_ci[1] === constr.moi_index
end

function delete_constraint_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    constrs = create_array_of_constrs(1, CL.MasterBranchConstr)
    constr = constrs[1]
    CL.add_constraint(problem, constr)
    @test constr.moi_index == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(1)
    CL.delete_constraint(problem, constr)
    list_of_ci = MOI.get(problem.optimizer, MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}())
    @test length(list_of_ci) == 0
    @test constr.prob_ref == -1
end

function add_membership_tests()
    problem = create_problem_empty()
    optimizer = GLPK.Optimizer()
    CL.initialize_problem_optimizer(problem, optimizer)
    constrs = create_array_of_constrs(1, CL.Constraint)
    constr = constrs[1]
    vars = create_array_of_vars(1, CL.Variable)
    var = vars[1]
    var.moi_index = MOI.add_variable(problem.optimizer)
    constr.moi_index = MOI.add_constraint(problem.optimizer, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0), MOI.LessThan(constr.cost_rhs))
    CL.add_membership(problem, var, constr, 1.0)
    @test var.member_coef_map[constr] == 1.0
    @test constr.member_coef_map[var] == 1.0
    constr_function = MOI.get(problem.optimizer, MOI.ConstraintFunction(), constr.moi_index)
    @test constr_function.terms[1].coefficient == 1.0
    @test constr_function.terms[1].variable_index == var.moi_index

    constrs = create_array_of_constrs(1, CL.MasterConstr)
    constr = constrs[1]
    vars = create_array_of_vars(1, CL.SubprobVar)
    var = vars[1]
    var.moi_index = MOI.add_variable(problem.optimizer)
    constr.moi_index = MOI.add_constraint(problem.optimizer, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0), MOI.LessThan(constr.cost_rhs))
    CL.add_membership(problem, var, constr, 1.0)
    @test var.master_constr_coef_map[constr] == 1.0
    @test constr.subprob_var_coef_map[var] == 1.0

    constrs = create_array_of_constrs(1, CL.MasterConstr)
    constr = constrs[1]
    vars = create_array_of_vars(1, CL.MasterVar)
    var = vars[1]
    var.moi_index = MOI.add_variable(problem.optimizer)
    constr.moi_index = MOI.add_constraint(problem.optimizer, MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0), MOI.LessThan(constr.cost_rhs))
    CL.add_membership(problem, var, constr, 1.0)
    @test var.member_coef_map[constr] == 1.0
    @test constr.member_coef_map[var] == 1.0
    constr_function = MOI.get(problem.optimizer, MOI.ConstraintFunction(), constr.moi_index)
    @test constr_function.terms[1].coefficient == 1.0
    @test constr_function.terms[1].variable_index == var.moi_index
end

function optimize!_tests()
    problem, vars, constr = create_problem_knapsack()
    status = CL.optimize!(problem)
    @test status == MOI.OPTIMAL
    problem, vars, constr = create_problem_knapsack(false)
    status = CL.optimize!(problem)
    @test MOI.get(problem.optimizer, MOI.ResultCount()) == 0
    problem.optimizer = nothing
    try CL.optimize!(problem)
        error("Test error : Optimzier was set to empty, but no error was returned.")
    catch err
        @test err == ErrorException("The problem has no optimizer attached")
    end
end

function optimize_tests()
    problem, vars, constr = create_problem_knapsack()
    optimizer = problem.optimizer
    problem.optimizer = nothing
    try CL.optimize!(problem)
        error("Optimzier was set to empty, but no error was returned")
    catch err
        @test err == ErrorException("The problem has no optimizer attached")
    end
    (status, primal_sol, dual_sol) = CL.optimize(problem, optimizer)
    @test status == MOI.OPTIMAL
    @test MOI.get(optimizer, MOI.ResultCount()) == 1
    @test length(primal_sol.var_val_map) == 2
    @test dual_sol == nothing
end

function extended_problem_tests()
    params = CL.Params()
    callback = CL.Callback()
    prob_counter = CL.ProblemCounter(-1) # like cplex convention of prob_ref
    vc_counter = CL.VarConstrCounter(0)
    extended_problem = CL.Reformulation(prob_counter, vc_counter, params,
                                          params.cut_up, params.cut_lo)
    @test prob_counter.value == 0
end

function initialize_extended_problem_optimizer_tests()
    params = CL.Params()
    callback = CL.Callback()
    prob_counter = CL.ProblemCounter(-1)
    vc_counter = CL.VarConstrCounter(0)
    extended_problem = CL.Reformulation(prob_counter, vc_counter, params,
                                          params.cut_up, params.cut_lo)
    subprob = CL.SimpleCompactProblem(prob_counter, vc_counter)
    push!(extended_problem.pricing_vect, subprob)
    problem_idx_optimizer_map = Dict{Int,MOI.AbstractOptimizer}()
    opt_1 = GLPK.Optimizer()
    opt_2 = GLPK.Optimizer()
    problem_idx_optimizer_map[0] = opt_1
    problem_idx_optimizer_map[1] = opt_2
    CL.initialize_problem_optimizer(extended_problem, problem_idx_optimizer_map)
    @test extended_problem.master_problem.optimizer != nothing
    @test extended_problem.pricing_vect[1] != nothing
end

function add_convexity_constraints_tests()
    params = CL.Params()
    callback = CL.Callback()
    prob_counter = CL.ProblemCounter(-1)
    vc_counter = CL.VarConstrCounter(0)
    extended_problem = CL.Reformulation(prob_counter, vc_counter, params,
                                          params.cut_up, params.cut_lo)
    subprob = CL.SimpleCompactProblem(prob_counter, vc_counter)
    push!(extended_problem.pricing_vect, subprob)
    CL.add_convexity_constraints(extended_problem, subprob, 1, 1)
    @test length(extended_problem.master_problem.constr_manager.active_static_list) == 2
    @test length(extended_problem.pricing_convexity_lbs) == 1
    @test length(extended_problem.pricing_convexity_ubs) == 1
end

function add_artificial_variables_tests()
    params = CL.Params()
    callback = CL.Callback()
    prob_counter = CL.ProblemCounter(-1)
    vc_counter = CL.VarConstrCounter(0)
    extended_problem = CL.Reformulation(prob_counter, vc_counter, params,
                                          params.cut_up, params.cut_lo)
    CL.add_artificial_variables(extended_problem)
    @test length(extended_problem.master_problem.var_manager.active_static_list) == 2
end

function get_problem_tests()
    params = CL.Params()
    callback = CL.Callback()
    prob_counter = CL.ProblemCounter(-1)
    vc_counter = CL.VarConstrCounter(0)
    extended_problem = CL.Reformulation(prob_counter, vc_counter, params,
                                          params.cut_up, params.cut_lo)
    subprob = CL.SimpleCompactProblem(prob_counter, vc_counter)
    push!(extended_problem.pricing_vect, subprob)
    CL.set_prob_ref_to_problem_dict(extended_problem)
    @test extended_problem.problem_ref_to_problem == Dict{Int,CL.Problem}(
        0 => extended_problem.master_problem,
        1 => subprob
    )
    @test CL.get_problem(extended_problem, 0) == extended_problem.master_problem
    @test CL.get_problem(extended_problem, 1) == subprob

end

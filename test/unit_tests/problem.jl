function problem_unit_tests()

    clear_tests()
    add_var_in_manager_tests()
    add_and_remove_constr_in_manager_tests()
    problem_counter_tests()
    initialize_problem_optimizer_tests()
    set_optimizer_obj_tests()
    fill_primal_sol_tests()
    retreive_primal_sol_tests()
    retreive_dual_sol_tests()
    is_sol_integer_tests()
    add_variable_tests()

end

function clear_tests()
    basis = CL.LpBasisRecord("basis_1")
    vars_vec = create_array_of_vars(10, CL.Variable)
    vars = [CL.VarMpFormStatus(vars_vec[i], 1) for i in 1:10]
    constrs_vec = create_array_of_constrs(10)
    constrs = [CL.ConstrMpFormStatus(constrs_vec[i], 1) for i in 1:10]
    basis.vars_in_basis = vars
    basis.constr_in_basis = constrs
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
        error("Status Active and flag z are not supported")
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
        error("Status Active and flag z are not supported")
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
        error("Status Active and flag z are not supported")
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
    @test MOI.get(problem.optimizer, MOI.ObjectiveSense()) == MOI.MinSense
end

function set_optimizer_obj_tests()
    problem, vars, constr = create_problem_1()
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
    problem, vars, constr = create_problem_1()
    MOI.optimize!(problem.optimizer)
    sol = Dict{CL.Variable,Float64}()
    CL.fill_primal_sol(problem, sol, problem.var_manager.active_static_list)
    @test sol[vars[4]] == 1.0
    @test sol[vars[2]] == 1.0
    @test length(sol) == 2
end

function retreive_primal_sol_tests()
    problem = create_problem_empty()
    try CL.retreive_primal_sol(problem)
        error("Problem has no optimizer")
    catch err
        @test err == ErrorException("The problem has no optimizer attached")
    end
    problem, vars, constr = create_problem_1()
    MOI.optimize!(problem.optimizer)
    CL.retreive_primal_sol(problem)
    sol = problem.primal_sols[end].var_val_map
    @test sol[vars[4]] == 1.0
    @test sol[vars[2]] == 1.0
    @test length(sol) == 2
end

function retreive_dual_sol_tests()
    ## Not working properly
    problem = create_problem_empty()
    try CL.retreive_dual_sol(problem)
        error("Problem has no optimizer")
    catch err
        @test err == ErrorException("The problem has no optimizer attached")
    end
    problem, vars, constr = create_problem_1()
    MOI.optimize!(problem.optimizer)
    CL.retreive_dual_sol(problem)
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
    vars[1].lower_bound = 0.0
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

    vars[2].vc_type = 'B'
    vars[2].upper_bound = 1.0
    vars[2].lower_bound = 0.1
    CL.add_variable(problem, vars[2])
    objf = MOI.get(problem.optimizer,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}())
    @test length(objf.terms) == 2
    @test objf.terms[2].coefficient == vars[2].cost_rhs
    @test objf.terms[2].variable_index == vars[2].moi_index
    list_of_ci = MOI.get(problem.optimizer,
    MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.Interval{Float64}}())
    @test length(list_of_ci) == 1
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[1]) == MOI.SingleVariable(vars[2].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[1]) == MOI.Interval{Float64}(1.0,1.0)

    vars[3].vc_type = 'I'
    CL.add_variable(problem, vars[3])
    list_of_ci = MOI.get(problem.optimizer,
    MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.Integer}())
    @test length(list_of_ci) == 1
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[1]) == MOI.SingleVariable(vars[3].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[1]) == MOI.Integer()

    vars[4].vc_type = 'C'
    vars[4].lower_bound = 5.0
    vars[4].upper_bound = 10.0
    CL.add_variable(problem, vars[4])
    list_of_ci = MOI.get(problem.optimizer,
    MOI.ListOfConstraintIndices{MOI.SingleVariable,MOI.Interval{Float64}}())
    @test length(list_of_ci) == 3
    @test MOI.get(problem.optimizer, MOI.ConstraintFunction(), list_of_ci[3]) == MOI.SingleVariable(vars[4].moi_index)
    @test MOI.get(problem.optimizer, MOI.ConstraintSet(), list_of_ci[3]) == MOI.Interval{Float64}(vars[4].lower_bound,vars[4].upper_bound)

    # vars = create_array_of_vars(4, Cl.SubprobVar)
    # vc_counter = CL.VarConstrCounter(4)
    # sol = CL.PrimalSolution(0.0, Dict{CL.Variable,Float64}())
    # vals = [1.0, 0.5, 2.0, 0.0]
    # for i in 1:length(vals)
    #     sol.var_val_map[vars[i]] = vals[i]
    # end
    # mc = CL.MasterColumn(vc_counter, sol)
    # CL.add_variable(problem, mc)

end

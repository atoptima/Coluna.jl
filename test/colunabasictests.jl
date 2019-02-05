function testdefaultbuilders()
    ## Problem builder
    counter = CL.VarConstrCounter(0)
    x1 = CL.VarConstr(counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0)
    x2 = CL.VarConstr(x1, counter)
    x3 = CL.Variable(counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0)
    x4 = CL.Variable(x3, counter)
    x5 = CL.SubprobVar(counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0,
                       -Inf, Inf, -Inf, Inf)
    x6 = CL.MasterVar(counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0, 0.0, 10.0)
    x7 = CL.MasterVar(x3, counter)
    x7 = CL.MasterVar(x6, counter)

    constr1 = CL.Constraint(counter, "knapConstr", 5.0, 'L', 'M', 's')
    constr2 = CL.MasterConstr(counter, "knapConstr", 5.0, 'L', 'M', 's')


    ### Model constructors
    params = CL.Params()
    counter = CL.VarConstrCounter(0)
    prob_counter = CL.ProblemCounter(0)
    masteroptimizer = GLPK.Optimizer()
    master_problem = CL.SimpleCompactProblem(prob_counter, counter)
    pricingoptimizer = GLPK.Optimizer()
    pricing_probs = Vector{CL.Problem}()
    push!(pricing_probs, CL.SimpleCompactProblem(prob_counter, counter))
    callback = CL.Callback()
    extended_problem = CL.ExtendedProblem(prob_counter, counter,
                       params, params.cut_up, params.cut_lo)
    model = CL.ModelConstructor()


    ### Info constructors
    # stab_info = CL.StabilizationInfo(master_problem, params)
    # lp_basis = CL.LpBasisRecord()
    # cg_eval_info = CL.ColGenEvalInfo(stab_info, lp_basis, 0.5)
    # lp_eval_info = CL.LpEvalInfo(stab_info)


    ### Algorithms constructors
    alg_setup_node = CL.AlgToSetupNode(extended_problem,
        CL.ProblemSetupInfo(0), false)
    alg_preprocess_node = CL.AlgToPreprocessNode(extended_problem)
    alg_eval_node = CL.AlgToEvalNode(extended_problem)
    alg_to_eval_by_lp = CL.AlgToEvalNodeByLp(extended_problem)
    alg_to_eval_by_cg = CL.AlgToEvalNodeBySimplexColGen(extended_problem)
    alg_setdown_node = CL.AlgToSetdownNode(extended_problem)
    alg_vect_primal_heur_node = CL.AlgToPrimalHeurInNode[]
    alg_generate_children_nodes = CL.AlgToGenerateChildrenNodes(extended_problem)
    usual_branching_algo = CL.UsualBranchingAlg(extended_problem)


    ### Node constructors
    rootNode = CL.Node(model.extended_problem, params.cut_lo, CL.ProblemSetupInfo(0))
    child1 = CL.NodeWithParent(model.extended_problem, rootNode)
end

function testpuremaster()
    counter = CL.VarConstrCounter(0)
    prob_counter = CL.ProblemCounter(0)
    problem = CL.SimpleCompactProblem(prob_counter, counter)
    CL.initialize_problem_optimizer(problem, GLPK.Optimizer())


    x1 = CL.MasterVar(counter, "x1", -10.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x2 = CL.MasterVar(counter, "x2", -15.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)
    x3 = CL.MasterVar(counter, "x3", -20.0, 'P', 'C', 's', 'U', 1.0, 0.0, 1.0)

    CL.add_variable(problem, x1; update_moi = true)
    CL.add_variable(problem, x2; update_moi = true)
    CL.add_variable(problem, x3; update_moi = true)

    constr = CL.MasterConstr(counter, "knapConstr", 5.0, 'L', 'M', 's')

    CL.add_constraint(problem, constr; update_moi = true)

    CL.add_membership(x1, constr, 2.0; optimizer = problem.optimizer)
    CL.add_membership(x2, constr, 3.0; optimizer = problem.optimizer)
    CL.add_membership(x3, constr, 4.0; optimizer = problem.optimizer)

    CL.optimize!(problem)

    @test MOI.get(problem.optimizer, MOI.ObjectiveValue()) == -25
end

function branch_and_bound_test_instance()
    ### Model constructors
    model = CL.ModelConstructor()
    params = model.params
    callback = model.callback
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    master_problem = extended_problem.master_problem
    model.problemidx_optimizer_map[master_problem.prob_ref] = GLPK.Optimizer()
    CL.set_model_optimizers(model)


    x1 = CL.MasterVar(master_problem.counter, "x1", -10.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
    x2 = CL.MasterVar(master_problem.counter, "x2", -15.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
    x3 = CL.MasterVar(master_problem.counter, "x3", -20.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)
    x4 = CL.MasterVar(master_problem.counter, "x4", -25.0, 'P', 'I', 's', 'U', 1.0, 0.0, 1.0)

    CL.add_variable(master_problem, x1; update_moi = true)
    CL.add_variable(master_problem, x2; update_moi = true)
    CL.add_variable(master_problem, x3; update_moi = true)
    CL.add_variable(master_problem, x4; update_moi = true)

    constr = CL.MasterConstr(master_problem.counter, "knapConstr_", 8.0, 'L', 'M', 's')

    CL.add_constraint(master_problem, constr; update_moi = true)

    CL.add_membership(x1, constr, 2.0; optimizer = master_problem.optimizer)
    CL.add_membership(x2, constr, 3.0; optimizer = master_problem.optimizer)
    CL.add_membership(x3, constr, 4.0; optimizer = master_problem.optimizer)
    CL.add_membership(x4, constr, 5.0; optimizer = master_problem.optimizer)

    CL.solve(model)

    @test model.extended_problem.primal_inc_bound == -40.0
end


function branch_and_bound_bigger_instances()
    atol = rtol = 0.000001
    @testset "result test" begin
    n_items = 4
    nb_bins = 3
    profits = [-10.0, -15.0, -20.0, -50.0]
    weights = [  4.0,   5.0,   6.0,  10.0]
    binscap = [ 10.0,  2.0,  10.0]
    model = build_coluna_model(n_items, nb_bins, profits, weights, binscap)
    CL.solve(model)
    @test model.extended_problem.primal_inc_bound == -80.0
    of_value = 0.0
    for var_val in model.extended_problem.solution.var_val_map
        of_value += var_val.first.cost_rhs * var_val.second
    end
    @test of_value == model.extended_problem.solution.cost == model.extended_problem.primal_inc_bound

    # n_items = 10
    # nb_bins = 5
    # profits = [-10.0, -15.0, -20.0, -50.0,  15.0, -10.0,  -5.0, -12.0, -10.0,  -8.0]
    # weights = [  4.0,   5.0,   6.0,  10.0,   1.0,   3.0,   5.0,   6.0,   4.0,   4.0]
    # binscap = [ 10.0,   2.0,  10.0,   5.0,   9.5]
    # model = build_coluna_model(n_items, nb_bins, profits, weights, binscap)
    # CL.solve(model)
    # used_bad_var = false
    # of_value = 0.0
    # for var_val in model.extended_problem.solution.var_val_map
    #     if occursin(r"x\(5,\d\)", var_val.first.name)
    #         used_bad_var = true
    #     end
    #     of_value += var_val.first.cost_rhs * var_val.second
    # end
    # @test -117 ≈ of_value atol=atol rtol=rtol
    # @test of_value ≈ model.extended_problem.solution.cost atol=atol rtol=rtol
    # @test of_value ≈ model.extended_problem.primal_inc_bound atol=atol rtol=rtol
    # @test used_bad_var == false
    end
end

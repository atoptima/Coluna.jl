
function testcolgenatroot()
    model = CL.ModelConstructor()
    params = model.params
    callback = model.callback
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    
    master_problem = extended_problem.master_problem
    masteroptimizer = Cbc.CbcOptimizer()
    CL.initialize_problem_optimizer(master_problem, masteroptimizer)

    pricingoptimizer = Cbc.CbcOptimizer()
    pricingprob = CL.SimpleCompactProblem(counter)
    CL.initialize_problem_optimizer(pricingprob, pricingoptimizer)
    push!(model.extended_problem.pricing_vect, pricingprob)

    #subproblem vars
    x1 = CL.SubprobVar(counter, "x1", 0.0, 'P', 'C', 's', 'U', 1.0, 
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    x2 = CL.SubprobVar(counter, "x2", 0.0, 'P', 'C', 's', 'U', 1.0, 
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    x3 = CL.SubprobVar(counter, "x3", 0.0, 'P', 'C', 's', 'U', 1.0, 
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    y = CL.SubprobVar(counter, "x3", 1.0, 'P', 'C', 's', 'U', 1.0, 
                       1.0, 1.0, -Inf, Inf, -Inf, Inf)

    CL.add_variable(pricingprob, x1)
    CL.add_variable(pricingprob, x2)
    CL.add_variable(pricingprob, x3)
    CL.add_variable(pricingprob, y)

    #subproblem constrs
    knp_constr = CL.Constraint(counter, "knp_constr", 0.0, 'L', 'M', 's')

    CL.add_constraint(pricingprob, knp_constr)

    CL.add_membership(x1, knp_constr, pricingprob, 3.0)
    CL.add_membership(x2, knp_constr, pricingprob, 4.0)
    CL.add_membership(x3, knp_constr, pricingprob, 5.0)
    CL.add_membership(y, knp_constr, pricingprob, -8.0)

    # master constraints
    cov_1_constr = CL.MasterConstr(master_problem.counter, "cov_1_constr", 0.0,
                                   'L', 'M', 's')
    cov_2_constr = CL.MasterConstr(master_problem.counter, "cov_2_constr", 0.0,
                                   'L', 'M', 's')
    cov_3_constr = CL.MasterConstr(master_problem.counter, "cov_3_constr", 0.0,
                                   'L', 'M', 's')

    CL.add_membership(x1, cov_1_constr, master_problem, 1.0)
    CL.add_membership(x2, cov_2_constr, master_problem, 1.0)
    CL.add_membership(x3, cov_3_constr, master_problem, 1.0)

    # model = CL.Model(CL.Params(), CL.VarConstrCounter(0), master_problem,
    #                  [pricingprob], [(0,100)], CL.PrimalSolution(), Inf, -Inf, 0)
    #
    
    # CL.solve(model)
end

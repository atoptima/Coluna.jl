
function testcolgenatroot()
    model = CL.ModelConstructor()
    params = model.params
    callback = model.callback
    extended_problem = model.extended_problem
    counter = model.extended_problem.counter
    prob_counter = model.prob_counter
    master_problem = extended_problem.master_problem
    masteroptimizer = GLPK.Optimizer()
    model.problemidx_optimizer_map[master_problem.prob_ref] = masteroptimizer

    pricingoptimizer = GLPK.Optimizer()
    pricingprob = CL.SimpleCompactProblem(prob_counter, counter)
    push!(extended_problem.pricing_vect, pricingprob)
    model.problemidx_optimizer_map[pricingprob.prob_ref] = pricingoptimizer
    CL.set_model_optimizers(model)

    #subproblem vars
    x1 = CL.SubprobVar(counter, "x1", 0.0, 'P', 'B', 's', 'U', 1.0, 
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    x2 = CL.SubprobVar(counter, "x2", 0.0, 'P', 'B', 's', 'U', 1.0, 
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    x3 = CL.SubprobVar(counter, "x3", 0.0, 'P', 'B', 's', 'U', 1.0, 
                       0.0, 1.0, -Inf, Inf, -Inf, Inf)
    y = CL.SubprobVar(counter, "y", 1.0, 'P', 'B', 's', 'U', 1.0, 
                       1.0, 1.0, -Inf, Inf, -Inf, Inf)
                       
    CL.add_variable(pricingprob, x1)
    CL.add_variable(pricingprob, x2)
    CL.add_variable(pricingprob, x3)
    CL.add_variable(pricingprob, y)

    #subproblem constrs
    knp_constr = CL.Constraint(counter, "knp_constr", 0.0, 'L', 'M', 's')

    CL.add_constraint(pricingprob, knp_constr)

    CL.add_membership(pricingprob, x1, knp_constr, 3.0)
    CL.add_membership(pricingprob, x2, knp_constr, 4.0)
    CL.add_membership(pricingprob, x3, knp_constr, 5.0)
    CL.add_membership(pricingprob, y, knp_constr, -8.0)

    # master var
    art_glob_var = CL.MasterVar(counter, "glob_art", 1000000.0, 'P', 'C', 
                                's', 'U', 1.0, 0.0, 1.0)
                                
    CL.add_variable(master_problem, art_glob_var)
    
    # master constraints
    cov_1_constr = CL.MasterConstr(master_problem.counter, "cov_1_constr", 1.0,
                                   'G', 'M', 's')
    cov_2_constr = CL.MasterConstr(master_problem.counter, "cov_2_constr", 1.0,
                                   'G', 'M', 's')
    cov_3_constr = CL.MasterConstr(master_problem.counter, "cov_3_constr", 1.0,
                                   'G', 'M', 's')
    convexity_constr = CL.MasterConstr(master_problem.counter, 
                                       "convexity_constr", 3.0, 'L', 'M', 's')
                                   
                                   
    CL.add_constraint(master_problem, cov_1_constr)                                                                                                       
    CL.add_constraint(master_problem, cov_2_constr)
    CL.add_constraint(master_problem, cov_3_constr)
    CL.add_constraint(master_problem, convexity_constr)

    CL.add_membership(master_problem, x1, cov_1_constr, 1.0)
    CL.add_membership(master_problem, x2, cov_2_constr, 1.0)
    CL.add_membership(master_problem, x3, cov_3_constr, 1.0)
    CL.add_membership(master_problem, y, convexity_constr, 1.0)
    
    CL.add_membership(master_problem, art_glob_var, cov_1_constr, 1.0)
    CL.add_membership(master_problem, art_glob_var, cov_2_constr, 1.0)
    CL.add_membership(master_problem, art_glob_var, cov_3_constr, 1.0)

    # model = CL.Model(CL.Params(), CL.VarConstrCounter(0), master_problem,
    #               [pricingprob], [(0,100)], CL.PrimalSolution(), Inf, -Inf, 0)

    CL.solve(model)
    
    @test model.extended_problem.primal_inc_bound == 2.0
end

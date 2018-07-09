
function testcolgenatroot()
    masteroptimizer = Cbc.CbcOptimizer()
    pricingprob = CL.SimpleProblem(masteroptimizer)

    pricingoptimizer = Cbc.CbcOptimizer()
    masterprob = CL.SimpleProblem(pricingoptimizer)
    
    #subproblem vars
    x1 = CL.SubProbVar(pricingprob, "x1", 0.0, 'P', 'C', 's', 'U', 1.0, 0.0, 
                       1.0, masterprob, -Inf, Inf, -Inf, Inf)
    x2 = CL.SubProbVar(pricingprob, "x2", 0.0, 'P', 'C', 's', 'U', 1.0, 0.0, 
                       1.0, masterprob, -Inf, Inf, -Inf, Inf)
    x3 = CL.SubProbVar(pricingprob, "x3", 0.0, 'P', 'C', 's', 'U', 1.0, 0.0, 
                       1.0, masterprob, -Inf, Inf, -Inf, Inf)
    y = CL.SubProbVar(pricingprob, "x3", 1.0, 'P', 'C', 's', 'U', 1.0, 1.0, 
                       1.0, masterprob, -Inf, Inf, -Inf, Inf)                   
    
    CL.addvariable(pricingprob, x1)
    CL.addvariable(pricingprob, x2)
    CL.addvariable(pricingprob, x3)
    CL.addvariable(pricingprob, y)

    #subproblem constrs
    knp_constr = CL.Constraint(pricingprob, "knp_constr", 0.0, 'L', 'M', 's')

    CL.addconstraint(pricingprob, knp_constr)

    CL.addmembership(x1, knp_constr, 3.0)
    CL.addmembership(x2, knp_constr, 4.0)
    CL.addmembership(x3, knp_constr, 5.0)
    CL.addmembership(y, knp_constr, -6.0)
    
    # master constraints
    cov_1_constr = CL.MasterConstr(pricingprob, "cov_1_constr", 0.0, 
                                   'L', 'M', 's')
    cov_2_constr = CL.MasterConstr(pricingprob, "cov_2_constr", 0.0, 
                                   'L', 'M', 's')
    cov_3_constr = CL.MasterConstr(pricingprob, "cov_3_constr", 0.0, 
                                   'L', 'M', 's')
    
    CL.addmembership(x1, cov_1_constr, 1.0)
    CL.addmembership(x2, cov_2_constr, 1.0)
    CL.addmembership(x3, cov_3_constr, 1.0)
        
    model = CL.Model(CL.Params(), CL.VarConstrCounter(0), masterprob, 
                     [pricingprob], [(0,100)], CL.Solution(), Inf, -Inf, 0)
    
    CL.solve(model)
end
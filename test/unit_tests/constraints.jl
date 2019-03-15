function constraints_unit_tests()

    master_constr_tests()
    convexity_constrs_tests()
    branch_constr_tests()

end

function master_constr_tests()
    vc_counter = CL.VarConstrCounter(0)
    mc_1 = CL.MasterConstr(vc_counter, "mc_1", 5.0, 'L', 'M', 's')
    @test mc_1.subprob_var_coef_map == Dict{CL.SubprobVar,Float64}()
    @test mc_1.subprob_var_coef_map == Dict{CL.Variable,Float64}()
end

function convexity_constrs_tests()
    vc_counter = CL.VarConstrCounter(0)
    conv_1 = CL.ConvexityConstr(vc_counter, "conv_1", 5.0, 'L', 'M', 's')
    @test conv_1.subprob_var_coef_map == Dict{CL.SubprobVar,Float64}()
    @test conv_1.subprob_var_coef_map == Dict{CL.Variable,Float64}()
end

function branch_constr_tests()
    vc_counter = CL.VarConstrCounter(0)
    brnch_1 = CL.MasterBranchConstr(vc_counter, "brnch_1", 5.0, 'L', 3)
    @test brnch_1.depth_when_generated == 3
end


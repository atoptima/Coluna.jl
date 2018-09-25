function variables_unit_tests()

    subprob_var_tests()
    master_var_tests()
    fract_part_test()
    is_value_integer_test()

end

function subprob_var_tests()
    vc_counter = CL.VarConstrCounter(0)
    spv_1 = CL.SubprobVar(vc_counter, "spv_1", 1.0, 'P', 'C', 's', 'U', 2.0, -Inf, Inf, -30.0, 30.0, -25.0, 25.0)
    @test spv_1.global_lb == -30.0
    @test spv_1.global_ub == 30.0
    @test spv_1.cur_global_lb == -25.0
    @test spv_1.cur_global_ub == 25.0
    @test spv_1.master_constr_coef_map == Dict{CL.Constraint,Float64}()
    @test spv_1.master_col_coef_map == Dict{CL.Variable,Float64}()

end

function master_var_tests()
    vc_counter = CL.VarConstrCounter(0)
    mv_1 = CL.MasterVar(vc_counter, "mv_1", 1.0, 'P', 'C', 's', 'U', 2.0, -Inf, Inf)
    @test mv_1.dualBoundContrib == 0.0
end

function fract_part_test()
    atol = rtol = 0.000001
    val_1 = 0.3
    val_2 = -0.6
    val_3 = 3.3
    @test CL.fract_part(val_1) ≈ 0.3 atol=atol rtol=rtol
    @test CL.fract_part(val_2) ≈ 0.4 atol=atol rtol=rtol
    @test CL.fract_part(val_3) ≈ 0.3 atol=atol rtol=rtol
end

function is_value_integer_test()
    val_1::Float64 = 1.0
    val_2::Float64 = 1.00000001
    @test CL.is_value_integer(val_1, 0.0) == true
    @test CL.is_value_integer(val_2, 0.00000001) == true
    @test CL.is_value_integer(val_2, 0.000000001) == false
end

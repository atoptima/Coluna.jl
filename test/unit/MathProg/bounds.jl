function mathprog_bounds()
    env = Coluna.Env(Coluna.Params())

    min_form = Coluna.MathProg.create_formulation!(
        env, Coluna.MathProg.Original();
        obj_sense = Coluna.MathProg.MinSense
    )

    max_form = Coluna.MathProg.create_formulation!(
        env, Coluna.MathProg.Original();
        obj_sense = Coluna.MathProg.MaxSense
    )

    @testset "Primal bound constructor" begin
        pb1 = Coluna.MathProg.PrimalBound(min_form)
        @test pb1 == Inf
        pb2 = Coluna.MathProg.PrimalBound(max_form)
        @test pb2 == -Inf
        pb3 = Coluna.MathProg.PrimalBound(min_form, 10)
        @test pb3 == 10
        @test_throws ErrorException Coluna.MathProg.PrimalBound(max_form, pb3)
    end

    @testset "Dual bound constructor" begin
        db1 = Coluna.MathProg.DualBound(min_form)
        @test db1 == -Inf
        db2 = Coluna.MathProg.DualBound(max_form)
        @test db2 == Inf
        db3 = Coluna.MathProg.DualBound(min_form, 150)
        @test db3 == 150
        @test_throws ErrorException Coluna.MathProg.DualBound(max_form, db3)
    end

    @testset "ObjValues constructor & private methods" begin
        obj = ObjValues(
            min_form;
            ip_primal_bound = 15.0,
            ip_dual_bound = 12.0,
            lp_primal_bound = 66,
            lp_dual_bound = π
        )

        @test obj.ip_primal_bound == 15.0
        @test obj.ip_dual_bound == 12.0
        @test obj.lp_primal_bound == 66
        @test obj.lp_dual_bound == float(π) # precision...

        # Gap methods are already tested in containers/solsandbounds.jl

        @test Coluna.MathProg._update_ip_primal_bound!(obj, PrimalBound(min_form, 16.0)) == false
        @test Coluna.MathProg._update_ip_primal_bound!(obj, PrimalBound(min_form, 14.0)) == true

        @test Coluna.MathProg._update_lp_primal_bound!(obj, PrimalBound(min_form, 67.0)) == false
        @test Coluna.MathProg._update_lp_primal_bound!(obj, PrimalBound(min_form, 65.0)) == true

        @test Coluna.MathProg._update_ip_dual_bound!(obj, DualBound(min_form, 11.0)) == false
        @test Coluna.MathProg._update_ip_dual_bound!(obj, DualBound(min_form, 13.0)) == true

        @test Coluna.MathProg._update_lp_dual_bound!(obj, DualBound(min_form, 3.0)) == false
        @test Coluna.MathProg._update_lp_dual_bound!(obj, DualBound(min_form, 3.2)) == true

        @test obj.ip_primal_bound == 14.0
        @test obj.ip_dual_bound == 13.0
        @test obj.lp_primal_bound == 65
        @test obj.lp_dual_bound == 3.2
    end
    return
end
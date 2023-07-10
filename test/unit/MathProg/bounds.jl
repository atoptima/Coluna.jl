function primal_bound_constructor()
    env = Coluna.Env{ClMP.VarId}(Coluna.Params())

    min_form = ClMP.create_formulation!(
        env, ClMP.Original();
        obj_sense = ClMP.MinSense
    )

    max_form = ClMP.create_formulation!(
        env, ClMP.Original();
        obj_sense = ClMP.MaxSense
    )

    pb1 = ClMP.PrimalBound(min_form)
    @test pb1 == Inf
    pb2 = ClMP.PrimalBound(max_form)
    @test pb2 == -Inf
    pb3 = ClMP.PrimalBound(min_form, 10)
    @test pb3 == 10
    @test_throws AssertionError ClMP.PrimalBound(max_form, pb3)
end
register!(unit_tests, "bounds", primal_bound_constructor)

function dual_bound_constructor()
    env = Coluna.Env{ClMP.VarId}(Coluna.Params())

    min_form = ClMP.create_formulation!(
        env, ClMP.Original();
        obj_sense = ClMP.MinSense
    )

    max_form = ClMP.create_formulation!(
        env, ClMP.Original();
        obj_sense = ClMP.MaxSense
    )

    db1 = ClMP.DualBound(min_form)
    @test db1 == -Inf
    db2 = ClMP.DualBound(max_form)
    @test db2 == Inf
    db3 = ClMP.DualBound(min_form, 150)
    @test db3 == 150
    @test_throws AssertionError ClMP.DualBound(max_form, db3)
end
register!(unit_tests, "bounds", dual_bound_constructor)

function obj_values_constructor()
    env = Coluna.Env{ClMP.VarId}(Coluna.Params())

    min_form = ClMP.create_formulation!(
        env, ClMP.Original();
        obj_sense = ClMP.MinSense
    )

    obj = ClMP.ObjValues(
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

    @test ClMP._update_ip_primal_bound!(obj, ClMP.PrimalBound(min_form, 16.0)) == false
    @test ClMP._update_ip_primal_bound!(obj, ClMP.PrimalBound(min_form, 14.0)) == true

    @test ClMP._update_lp_primal_bound!(obj, ClMP.PrimalBound(min_form, 67.0)) == false
    @test ClMP._update_lp_primal_bound!(obj, ClMP.PrimalBound(min_form, 65.0)) == true

    @test ClMP._update_ip_dual_bound!(obj, ClMP.DualBound(min_form, 11.0)) == false
    @test ClMP._update_ip_dual_bound!(obj, ClMP.DualBound(min_form, 13.0)) == true

    @test ClMP._update_lp_dual_bound!(obj, ClMP.DualBound(min_form, 3.0)) == false
    @test ClMP._update_lp_dual_bound!(obj, ClMP.DualBound(min_form, 3.2)) == true

    @test obj.ip_primal_bound == 14.0
    @test obj.ip_dual_bound == 13.0
    @test obj.lp_primal_bound == 65
end
register!(unit_tests, "bounds", obj_values_constructor)

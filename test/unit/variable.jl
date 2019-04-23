function variable_unit_tests()
   # variable_getters_setters_unit_tests()
   # variable_updatesense!_unit_tests()
  #  variable_set!_unit_tests()
end

function variable_getters_setters_unit_tests()
    v = CL.Variable("variable")
    @test CL.get_form(v) == 0
    @test CL.get_name(v) == "variable"
    @test CL.get_cost(v) == 0.0
    @test CL.get_lb(v) == -Inf
    @test CL.get_ub(v) == Inf
    @test CL.get_kind(v) == CL.Continuous
    @test CL.get_sense(v) == CL.Free

    @test CL.setform!(v, 1) == 1
    @test CL.get_form(v) == 1
    @test CL.setname!(v, "elbairav") == "elbairav"
    @test CL.get_name(v) == "elbairav"
    @test CL.set_cost!(v, 1.0) == 1.0
    @test CL.get_cost(v) == 1.0
    @test CL.set_lb!(v, -1.0) == -1.0
    @test CL.get_lb(v) == -1.0
    @test CL.set_ub!(v, 1.0) == 1.0
    @test CL.get_ub(v) == 1.0
    @test CL.set_kind!(v, CL.Integ) == CL.Integ
    @test CL.get_kind(v) == CL.Integ
    @test CL.set_sense!(v, CL.Positive) == CL.Positive  
    @test CL.get_sense(v) == CL.Positive
    return
end

function variable_updatesense!_unit_tests()
    v = CL.Variable("variable")
    CL.set_lb!(v, 0.0)
    CL.set_ub!(v, 0.0)
    CL.updatesense!(v)
    @test CL.get_sense(v) == CL.Positive

    CL.set_lb!(v, -1.0)
    CL.set_ub!(v, 1.0)
    CL.updatesense!(v)
    @test CL.get_sense(v) == CL.Free

    CL.set_ub!(v, 0.0)
    CL.updatesense!(v)
    @test CL.get_sense(v) == CL.Negative
    return
end

function variable_set!_unit_tests()
    v = CL.Variable("variable")

    function _test_var_lb_ub_kind_sense(var, l, u, k, s)
        @test CL.get_lb(var) == l
        @test CL.get_ub(var) == u
        @test CL.get_kind(var) == k
        @test CL.get_sense(var) == s
    end

    CL.set!(v, MOI.ZeroOne())
    _test_var_lb_ub_kind_sense(v, 0.0, 1.0, CL.Binary, CL.Positive)

    CL.set_kind!(v, CL.Continuous)
    CL.set!(v, MOI.GreaterThan{Int}(1))
    _test_var_lb_ub_kind_sense(v, 1.0, 1.0, CL.Continuous, CL.Positive)

    CL.set_lb!(v, -Inf)
    CL.set_ub!(v, Inf)
    CL.set!(v, MOI.LessThan{Int}(2))
    _test_var_lb_ub_kind_sense(v, -Inf, 2.0, CL.Continuous, CL.Free)

    CL.set!(v, MOI.EqualTo{Float64}(-1.0))
    _test_var_lb_ub_kind_sense(v, -1.0, -1.0, CL.Continuous, CL.Negative)
    return
end

function variable_unit_tests()
    variable_getters_setters_unit_tests()
    variable_updatesense!_unit_tests()
    variable_set!_unit_tests()
end

function variable_getters_setters_unit_tests()
    v = CL.Variable("variable")
    @test CL.getform(v) == 0
    @test CL.getname(v) == "variable"
    @test CL.getcost(v) == 0.0
    @test CL.getlb(v) == -Inf
    @test CL.getub(v) == Inf
    @test CL.getkind(v) == CL.Continuous
    @test CL.getsense(v) == CL.Free

    @test CL.setform!(v, 1) == 1
    @test CL.getform(v) == 1
    @test CL.setname!(v, "elbairav") == "elbairav"
    @test CL.getname(v) == "elbairav"
    @test CL.setcost!(v, 1.0) == 1.0
    @test CL.getcost(v) == 1.0
    @test CL.setlb!(v, -1.0) == -1.0
    @test CL.getlb(v) == -1.0
    @test CL.setub!(v, 1.0) == 1.0
    @test CL.getub(v) == 1.0
    @test CL.setkind!(v, CL.Integ) == CL.Integ
    @test CL.getkind(v) == CL.Integ
    @test CL.setsense!(v, CL.Positive) == CL.Positive  
    @test CL.getsense(v) == CL.Positive
    return
end

function variable_updatesense!_unit_tests()
    v = CL.Variable("variable")
    CL.setlb!(v, 0.0)
    CL.setub!(v, 0.0)
    CL.updatesense!(v)
    @test CL.getsense(v) == CL.Positive

    CL.setlb!(v, -1.0)
    CL.setub!(v, 1.0)
    CL.updatesense!(v)
    @test CL.getsense(v) == CL.Free

    CL.setub!(v, 0.0)
    CL.updatesense!(v)
    @test CL.getsense(v) == CL.Negative
    return
end

function variable_set!_unit_tests()
    v = CL.Variable("variable")

    function _test_var_lb_ub_kind_sense(var, l, u, k, s)
        @test CL.getlb(var) == l
        @test CL.getub(var) == u
        @test CL.getkind(var) == k
        @test CL.getsense(var) == s
    end

    CL.set!(v, MOI.ZeroOne())
    _test_var_lb_ub_kind_sense(v, 0.0, 1.0, CL.Binary, CL.Positive)

    CL.setkind!(v, CL.Continuous)
    CL.set!(v, MOI.GreaterThan{Int}(1))
    _test_var_lb_ub_kind_sense(v, 1.0, 1.0, CL.Continuous, CL.Positive)

    CL.setlb!(v, -Inf)
    CL.setub!(v, Inf)
    CL.set!(v, MOI.LessThan{Int}(2))
    _test_var_lb_ub_kind_sense(v, -Inf, 2.0, CL.Continuous, CL.Free)

    CL.set!(v, MOI.EqualTo{Float64}(-1.0))
    _test_var_lb_ub_kind_sense(v, -1.0, -1.0, CL.Continuous, CL.Negative)
    return
end
function variable_unit_tests()
    var_data_getters_and_setters_tests()
    moi_var_record_getters_and_setters_tests()
    variable_getters_and_setters_tests()
end

function var_data_getters_and_setters_tests()

    v_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = false, is_explicit = false
    )

    @test CL.get_cost(v_data) == 13.0
    @test CL.get_lb(v_data) == -10.0
    @test CL.get_ub(v_data) == 100.0

    CL.set_cost!(v_data, -113.0)
    CL.set_lb!(v_data, -113.0)
    CL.set_ub!(v_data, -113.0)

    @test CL.get_cost(v_data) == -113.0
    @test CL.get_lb(v_data) == -113.0
    @test CL.get_ub(v_data) == -113.0

    CL.set_kind!(v_data, CL.Binary)
    @test CL.get_kind(v_data) == CL.Binary
    @test CL.get_lb(v_data) == 0.0
    @test CL.get_ub(v_data) == -113.0

    CL.set_kind!(v_data, CL.Integ)
    @test CL.get_kind(v_data) == CL.Integ
    @test CL.get_lb(v_data) == 0.0
    @test CL.get_ub(v_data) == -113.0

end

function moi_var_record_getters_and_setters_tests()

    v_rec = CL.MoiVarRecord(
        ; index = CL.MoiVarIndex(-15)
    )

    @test CL.get_index(v_rec) == CL.MoiVarIndex(-15)
    @test CL.get_bounds(v_rec) == CL.MoiVarBound(-1)
    @test CL.get_kind(v_rec) == CL.MoiInteger(-1)

    CL.set_index!(v_rec, CL.MoiVarIndex(-20))
    CL.set_bounds!(v_rec, CL.MoiVarBound(10))
    CL.set_kind!(v_rec, CL.MoiBinary(13))

    @test CL.get_index(v_rec) == CL.MoiVarIndex(-20)
    @test CL.get_bounds(v_rec) == CL.MoiVarBound(10)
    @test CL.get_kind(v_rec) == CL.MoiBinary(13)

end

function variable_getters_and_setters_tests()

    v_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = false, is_explicit = false
    )

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MastRepBendSpVar;
        var_data = v_data
    )

    v.initial_data.cost = -1112.0
    v.cur_data.cost = 1013.0
    @test v.initial_data.cost == -1112.0

    CL.reset!(v)
    @test v.initial_data.cost == v.cur_data.cost == -1112.0
    @test v.initial_data.lower_bound == v.cur_data.lower_bound == -10.0
    @test v.initial_data.upper_bound == v.cur_data.upper_bound == 100.0
    @test v.initial_data.kind == v.cur_data.kind == CL.Continuous
    @test v.initial_data.sense == v.cur_data.sense == CL.Free
    @test v.initial_data.inc_val == v.cur_data.inc_val == -1.0
    @test v.initial_data.is_active == v.cur_data.is_active == false
    @test v.initial_data.is_explicit == v.cur_data.is_explicit == false

end

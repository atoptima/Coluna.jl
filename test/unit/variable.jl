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
    @test CL.getlb(v_data) == -10.0
    @test CL.getub(v_data) == 100.0

    CL.setcost!(v_data, -113.0)
    CL.set_lb!(v_data, -113.0)
    CL.set_ub!(v_data, -113.0)

    @test CL.get_cost(v_data) == -113.0
    @test CL.getlb(v_data) == -113.0
    @test CL.getub(v_data) == -113.0

    CL.setkind!(v_data, CL.Binary)
    @test CL.getkind(v_data) == CL.Binary
    @test CL.getlb(v_data) == 0.0
    @test CL.getub(v_data) == -113.0

    CL.setkind!(v_data, CL.Integ)
    @test CL.getkind(v_data) == CL.Integ
    @test CL.getlb(v_data) == 0.0
    @test CL.getub(v_data) == -113.0

end

function moi_var_record_getters_and_setters_tests()

    v_rec = CL.MoiVarRecord(
        ; index = CL.MoiVarIndex(-15)
    )

    @test CL.getindex(v_rec) == CL.MoiVarIndex(-15)
    @test CL.getbounds(v_rec) == CL.MoiVarBound(-1)
    @test CL.getkind(v_rec) == CL.MoiInteger(-1)

    CL.setindex!(v_rec, CL.MoiVarIndex(-20))
    CL.setbounds!(v_rec, CL.MoiVarBound(10))
    CL.setkind!(v_rec, CL.MoiBinary(13))

    @test CL.getindex(v_rec) == CL.MoiVarIndex(-20)
    @test CL.getbounds(v_rec) == CL.MoiVarBound(10)
    @test CL.getkind(v_rec) == CL.MoiBinary(13)

end

function variable_getters_and_setters_tests()

    v_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = false, is_explicit = false
    )

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MasterPureVar;
        var_data = v_data
    )

    @test CL.getperenecost(v) == CL.getcurcost(v) == CL.get_cost(CL.getcurdata(v)) == CL.get_cost(CL.getrecordeddata(v)) == 13.0
    @test CL.getperenelb(v) == CL.getcurlb(v) == CL.getlb(CL.getcurdata(v)) == CL.getlb(CL.getrecordeddata(v)) == -10.0
    @test CL.getpereneub(v) == CL.getcurub(v) == CL.getub(CL.getcurdata(v)) == CL.getub(CL.getrecordeddata(v)) == 100.0

    CL.setcurcost!(v, -134.0)
    CL.setcurlb!(v, -2001.9)
    CL.setcurub!(v, 2387.0)

    @test CL.getcurcost(v) == CL.get_cost(CL.getcurdata(v)) == -134.0
    @test CL.getcurlb(v) == CL.getlb(CL.getcurdata(v)) == -2001.9
    @test CL.getcurub(v) == CL.getub(CL.getcurdata(v)) == 2387.0
    @test CL.getperenecost(v) == CL.get_cost(CL.getrecordeddata(v)) == 13.0
    @test CL.getperenelb(v) == CL.getlb(CL.getrecordeddata(v)) == -10.0
    @test CL.getpereneub(v) == CL.getub(CL.getrecordeddata(v)) == 100.0

    CL.reset!(v)
    @test v.perene_data.cost == v.cur_data.cost == 13.0
    @test v.perene_data.lb == v.cur_data.lb == -10.0
    @test v.perene_data.ub == v.cur_data.ub == 100.0
    @test v.perene_data.kind == v.cur_data.kind == CL.Continuous
    @test v.perene_data.sense == v.cur_data.sense == CL.Free
    @test v.perene_data.inc_val == v.cur_data.inc_val == -1.0
    @test v.perene_data.is_explicit == v.cur_data.is_explicit == false
    @test v.perene_data.is_active == v.cur_data.is_active == false

end

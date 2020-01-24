function variable_unit_tests()
    var_data_getters_and_setters_tests()
    moi_var_record_getters_and_setters_tests()
    variable_getters_and_setters_tests()
    return
end

function var_data_getters_and_setters_tests()

    # v_data = ClF.VarData(
    #     ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
    #     sense = ClF.Free, is_active = false, is_explicit = false
    # )

    # @test ClF.getcost(v_data) == 13.0
    # @test ClF.getlb(v_data) == -10.0
    # @test ClF.getub(v_data) == 100.0

    # ClF.setcost!(v_data, -113.0)
    # ClF.setlb!(v_data, -113.0)
    # ClF.setub!(v_data, -113.0)

    # @test ClF.getcost(v_data) == -113.0
    # @test ClF.getlb(v_data) == -113.0
    # @test ClF.getub(v_data) == -113.0

    # ClF.setkind!(v_data, ClF.Binary)
    # @test ClF.getkind(v_data) == ClF.Binary
    # @test ClF.getlb(v_data) == 0.0
    # @test ClF.getub(v_data) == -113.0

    # ClF.setkind!(v_data, ClF.Integ)
    # @test ClF.getkind(v_data) == ClF.Integ
    # @test ClF.getlb(v_data) == 0.0
    # @test ClF.getub(v_data) == -113.0
    return
end

function moi_var_record_getters_and_setters_tests()

    v_rec = ClF.MoiVarRecord(
        ; index = ClF.MoiVarIndex(-15)
    )

    @test ClF.getindex(v_rec) == ClF.MoiVarIndex(-15)
    @test ClF.getbounds(v_rec) == ClF.MoiVarBound(-1)
    #@test ClF.getkind(v_rec) == ClF.MoiInteger(-1)

    ClF.setindex!(v_rec, ClF.MoiVarIndex(-20))
    ClF.setbounds!(v_rec, ClF.MoiVarBound(10))
    #ClF.setkind!(v_rec, ClF.MoiBinary(13))

    @test ClF.getindex(v_rec) == ClF.MoiVarIndex(-20)
    @test ClF.getbounds(v_rec) == ClF.MoiVarBound(10)
    #@test ClF.getkind(v_rec) == ClF.MoiBinary(13)
    return
end

function variable_getters_and_setters_tests()

    v_data = ClF.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        sense = ClF.Free, is_active = false, is_explicit = false
    )

    v = ClF.Variable(
        ClF.Id{ClF.Variable}(23, 10), "fake_var", ClF.MasterPureVar;
        var_data = v_data
    )

    #@test ClF.getperenecost(v) == ClF.getcurcost(v) == 13.0
    #@test ClF.getperenelb(v) == ClF.getcurlb(v) == -10.0
    #@test ClF.getpereneub(v) == ClF.getcurub(v) == 100.0

    #ClF.setcurcost!(v, -134.0)
    #ClF.setcurlb!(v, -2001.9)
    #ClF.setcurub!(v, 2387.0)

    #@test ClF.getcurcost(v) == -134.0
    #@test ClF.getcurlb(v) == -2001.9
    #@test ClF.getcurub(v) == 2387.0
    #@test ClF.getperenecost(v) == 13.0
    #@test ClF.getperenelb(v) == -10.0
    #@test ClF.getpereneub(v) == 100.0

    #ClF.reset!(v)
    #@test v.perene_data.cost == v.cur_data.cost == 13.0
    #@test v.perene_data.lb == v.cur_data.lb == -10.0
    #@test v.perene_data.ub == v.cur_data.ub == 100.0
    #@test v.perene_data.kind == v.cur_data.kind == ClF.Continuous
    #@test v.perene_data.sense == v.cur_data.sense == ClF.Free
    #@test v.perene_data.inc_val == v.cur_data.inc_val == -1.0
    #@test v.perene_data.is_explicit == v.cur_data.is_explicit == false
    #@test v.perene_data.is_active == v.cur_data.is_active == false
    return
end

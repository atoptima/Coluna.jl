function variable_unit_tests()
    moi_var_record_getters_and_setters_tests()
    variable_getters_and_setters_tests()
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
    form = create_formulation!(Env(Coluna.Params()), Original())
    
    v_data = ClF.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        is_active = false, is_explicit = false
    )

    v = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.MasterPureVar, 23, 10, false), "fake_var";
        var_data = v_data
    )

    ClF._addvar!(form, v)
    @test ClF.getperencost(form, v) == ClF.getcurcost(form, v) == 13.0
    @test ClF.getperenlb(form, v) == ClF.getcurlb(form, v) == -10.0
    @test ClF.getperenub(form, v) == ClF.getcurub(form, v) == 100.0

    ClF.setcurcost!(form, v, -134.0)
    ClF.setcurlb!(form, v, -2001.9)
    ClF.setcurub!(form, v, 2387.0)

    @test ClF.getcurcost(form, v) == -134.0
    @test ClF.getcurlb(form, v) == -2001.9
    @test ClF.getcurub(form, v) == 2387.0
    @test ClF.getperencost(form, v) == 13.0
    @test ClF.getperenlb(form, v) == -10.0
    @test ClF.getperenub(form, v) == 100.0

    ClF.reset!(form, v)
    @test ClF.getperencost(form, v) == ClF.getcurcost(form, v) == 13.0
    return
end

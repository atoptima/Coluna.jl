function getters_and_setters()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
        kind = ClMP.Integ, inc_val = 4.0
    )

    varid = ClMP.getid(var)

    @test ClMP.getperencost(form, varid) == 2.0
    @test ClMP.getperenlb(form, varid) == -1.0
    @test ClMP.getperenub(form, varid) == 1.0
    @test ClMP.getperensense(form, varid) == ClMP.Free
    @test ClMP.getperenkind(form, varid) == ClMP.Integ
    @test ClMP.getperenincval(form, varid) == 4.0

    @test ClMP.getcurcost(form, varid) == 2.0
    @test ClMP.getcurlb(form, varid) == -1.0
    @test ClMP.getcurub(form, varid) == 1.0
    @test ClMP.getcursense(form, varid) == ClMP.Free
    @test ClMP.getcurkind(form, varid) == ClMP.Integ
    @test ClMP.getcurincval(form, varid) == 4.0

    ClMP.setcurcost!(form, varid, 3.0)
    ClMP.setcurlb!(form, varid, -2.0)
    ClMP.setcurub!(form, varid, 2.0)
    ClMP.setcurkind!(form, varid, ClMP.Continuous)
    ClMP.setcurincval!(form, varid, 3.0)

    @test ClMP.getcurcost(form, varid) == 3.0
    @test ClMP.getcurlb(form, varid) == -2.0
    @test ClMP.getcurub(form, varid) == 2.0
    @test ClMP.getcursense(form, varid) == ClMP.Free
    @test ClMP.getcurkind(form, varid) == ClMP.Continuous
    @test ClMP.getcurincval(form, varid) == 3.0

    ClMP.reset!(form, varid)
    @test ClMP.getcurcost(form, varid) == 2.0
    @test ClMP.getcurlb(form, varid) == -1.0
    @test ClMP.getcurub(form, varid) == 1.0
    @test ClMP.getcursense(form, varid) == ClMP.Free
    @test ClMP.getcurkind(form, varid) == ClMP.Integ
    @test ClMP.getcurincval(form, varid) == 4.0
end
register!(unit_tests, "variables", getters_and_setters)

function bounds_of_binary_variable_1()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, kind = ClMP.Binary
    )

    @test ClMP.getperenlb(form, var) == 0.0
    @test ClMP.getperenub(form, var) == 1.0
    @test ClMP.getcurlb(form, var) == 0.0
    @test ClMP.getcurub(form, var) == 1.0

    ClMP.setperenlb!(form, var, -1.0)
    ClMP.setperenub!(form, var, 2.0)

    @test ClMP.getperenlb(form, var) == 0.0
    @test ClMP.getperenub(form, var) == 1.0
    @test ClMP.getcurlb(form, var) == 0.0
    @test ClMP.getcurub(form, var) == 1.0

    ClMP.setcurlb!(form, var, -1.1)
    ClMP.setcurub!(form, var, 2.1)

    @test ClMP.getcurlb(form, var) == 0.0
    @test ClMP.getcurub(form, var) == 1.0

    ClMP.setperenlb!(form, var, 0.1)
    ClMP.setperenub!(form, var, 0.9)

    @test ClMP.getperenlb(form, var) == 0.1
    @test ClMP.getperenub(form, var) == 0.9
    @test ClMP.getcurlb(form, var) == 0.1
    @test ClMP.getcurub(form, var) == 0.9

    ClMP.setcurlb!(form, var, 0.2)
    ClMP.setcurub!(form, var, 0.8)

    @test ClMP.getperenlb(form, var) == 0.1
    @test ClMP.getperenub(form, var) == 0.9
    @test ClMP.getcurlb(form, var) == 0.2
    @test ClMP.getcurub(form, var) == 0.8
end
register!(unit_tests, "variables", bounds_of_binary_variable_1)

function bounds_of_binary_variable_2()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, kind = ClMP.Continuous, lb = -10.0, ub = 10.0
    )

    @test ClMP.getperenlb(form, var) == -10.0
    @test ClMP.getperenub(form, var) == 10.0
    @test ClMP.getcurlb(form, var) == -10.0
    @test ClMP.getcurub(form, var) == 10.0

    ClMP.setperenkind!(form, var, ClMP.Binary)

    @test ClMP.getperenlb(form, var) == 0.0
    @test ClMP.getperenub(form, var) == 1.0
    @test ClMP.getcurlb(form, var) == 0.0
    @test ClMP.getcurub(form, var) == 1.0
end
register!(unit_tests, "variables", bounds_of_binary_variable_2)

function bounds_of_binary_variable_3()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, kind = ClMP.Continuous, lb = -10.0, ub = 10.0
    )

    @test ClMP.getperenlb(form, var) == -10.0
    @test ClMP.getperenub(form, var) == 10.0
    @test ClMP.getcurlb(form, var) == -10.0
    @test ClMP.getcurub(form, var) == 10.0

    ClMP.setcurkind!(form, var, ClMP.Binary)

    @test ClMP.getperenlb(form, var) == -10.0
    @test ClMP.getperenub(form, var) == 10.0
    @test ClMP.getcurlb(form, var) == 0.0
    @test ClMP.getcurub(form, var) == 1.0
end
register!(unit_tests, "variables", bounds_of_binary_variable_3)

function record()
    v_rec = ClMP.MoiVarRecord(; index = ClMP.MoiVarIndex(-15))

    @test ClMP.getmoiindex(v_rec) == ClMP.MoiVarIndex(-15)
    @test ClMP.getlowerbound(v_rec) == ClMP.MoiVarLowerBound(-1)
    @test ClMP.getupperbound(v_rec) == ClMP.MoiVarUpperBound(-1)

    ClMP.setmoiindex!(v_rec, ClMP.MoiVarIndex(-20))
    ClMP.setlowerbound!(v_rec, ClMP.MoiVarLowerBound(10))
    ClMP.setupperbound!(v_rec, ClMP.MoiVarUpperBound(20))

    @test ClMP.getmoiindex(v_rec) == ClMP.MoiVarIndex(-20)
    @test ClMP.getlowerbound(v_rec) == ClMP.MoiVarLowerBound(10)
    @test ClMP.getupperbound(v_rec) == ClMP.MoiVarUpperBound(20)
end
register!(unit_tests, "variables", record)

function fix_variable_1()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
        kind = ClMP.Integ, inc_val = 4.0
    )
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    varid = ClMP.getid(var)
    
    @test ClMP.iscuractive(form, var)
    @test ClMP.isexplicit(form, var)
    @test !ClMP.isfixed(form, var)
    @test !in(varid, form.manager.fixed_vars)

    ClMP.fix!(form, var, 0.0)
    @test ClMP.getcurub(form, var) == 0
    @test ClMP.getcurlb(form, var) == 0
    @test ClMP.getperenub(form, var) == 1
    @test ClMP.getperenlb(form, var) == -1
    @test ClMP.isfixed(form, var)
    @test !ClMP.iscuractive(form, var)
    @test in(varid, form.manager.fixed_vars)
end
register!(unit_tests, "variables", fix_variable_1)

function fix_variable_2()
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
        kind = ClMP.Integ, inc_val = 4.0
    )
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    varid = ClMP.getid(var)
    ClMP.deactivate!(form, varid)
    @test !ClMP.iscuractive(form, varid)
    ClMP.fix!(form, varid, 0)  # try to fix an unactive variable -> should not work.
    @test !ClMP.isfixed(form, varid)
    @test ClMP.getcurub(form, var) == 1
    @test ClMP.getcurlb(form, var) == -1
    @test ClMP.getperenub(form, var) == 1
    @test ClMP.getperenlb(form, var) == -1
end
register!(unit_tests, "variables", fix_variable_2)

function fix_variable_3()
    # sequential fix
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    var = ClMP.setvar!(
        form, "var1", ClMP.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
        kind = ClMP.Integ, inc_val = 4.0
    )
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    varid = ClMP.getid(var)
    @test !in(varid, form.manager.fixed_vars)

    ClMP.fix!(form, var, 0.0)
    @test ClMP.getcurub(form, var) == 0
    @test ClMP.getcurlb(form, var) == 0
    @test ClMP.getperenub(form, var) == 1
    @test ClMP.getperenlb(form, var) == -1
    @test ClMP.isfixed(form, var)
    @test !ClMP.iscuractive(form, var)
    @test in(varid, form.manager.fixed_vars)

    ClMP.unfix!(form, var)
    @test ClMP.getcurub(form, var) == 0
    @test ClMP.getcurlb(form, var) == 0
    @test ClMP.getperenub(form, var) == 1
    @test ClMP.getperenlb(form, var) == -1
    @test !ClMP.isfixed(form, var)
    @test ClMP.iscuractive(form, var)
    @test !in(varid, form.manager.fixed_vars)

    ClMP.fix!(form, var, 1.0)
    @test ClMP.getcurub(form, var) == 1
    @test ClMP.getcurlb(form, var) == 1
    @test ClMP.getperenub(form, var) == 1
    @test ClMP.getperenlb(form, var) == -1
    @test ClMP.isfixed(form, var)
    @test !ClMP.iscuractive(form, var)
    @test in(varid, form.manager.fixed_vars)
end
register!(unit_tests, "variables", fix_variable_3)

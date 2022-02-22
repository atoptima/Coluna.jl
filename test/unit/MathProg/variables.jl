function variables_unit_tests()
    getset_variables()
    return
end

function getset_variables()
    form = ClMP.create_formulation!(Env(Coluna.Params()), ClMP.Original())
    var = ClF.setvar!(
        form, "var1", ClF.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
        kind = ClF.Integ, inc_val = 4.0
    )

    varid = ClMP.getid(var)

    @test ClF.getperencost(form, varid) == 2.0
    @test ClF.getperenlb(form, varid) == -1.0
    @test ClF.getperenub(form, varid) == 1.0
    @test ClF.getperensense(form, varid) == ClF.Free
    @test ClF.getperenkind(form, varid) == ClF.Integ
    @test ClF.getperenincval(form, varid) == 4.0

    @test ClF.getcurcost(form, varid) == 2.0
    @test ClF.getcurlb(form, varid) == -1.0
    @test ClF.getcurub(form, varid) == 1.0
    @test ClF.getcursense(form, varid) == ClF.Free
    @test ClF.getcurkind(form, varid) == ClF.Integ
    @test ClF.getcurincval(form, varid) == 4.0

    ClF.setcurcost!(form, varid, 3.0)
    ClF.setcurlb!(form, varid, -2.0)
    ClF.setcurub!(form, varid, 2.0)
    ClF.setcurkind!(form, varid, ClF.Continuous)
    ClF.setcurincval!(form, varid, 3.0)

    @test ClF.getcurcost(form, varid) == 3.0
    @test ClF.getcurlb(form, varid) == -2.0
    @test ClF.getcurub(form, varid) == 2.0
    @test ClF.getcursense(form, varid) == ClF.Free
    @test ClF.getcurkind(form, varid) == ClF.Continuous
    @test ClF.getcurincval(form, varid) == 3.0

    ClF.reset!(form, varid)
    @test ClF.getcurcost(form, varid) == 2.0
    @test ClF.getcurlb(form, varid) == -1.0
    @test ClF.getcurub(form, varid) == 1.0
    @test ClF.getcursense(form, varid) == ClF.Free
    @test ClF.getcurkind(form, varid) == ClF.Integ
    @test ClF.getcurincval(form, varid) == 4.0
    return
end
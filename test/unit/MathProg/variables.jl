function variables_unit_tests()
    getset_variables()
    return
end

function createformulation()
    counter = ClF.Counter()
    return ClF.Formulation{ClF.Original}(counter)
end

function getset_variables()
    form = createformulation()
    var = ClF.setvar!(
        form, "var1", ClF.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0, 
        kind = ClF.Integ, inc_val = 4.0
    )

    @test ClF.getperencost(form, var) == 2.0
    @test ClF.getperenlb(form, var) == -1.0
    @test ClF.getperenub(form, var) == 1.0
    @test ClF.getperensense(form, var) == ClF.Free
    @test ClF.getperenkind(form, var) == ClF.Integ
    @test ClF.getperenincval(form, var) == 4.0

    @test ClF.getcurcost(form, var) == 2.0
    @test ClF.getcurlb(form, var) == -1.0
    @test ClF.getcurub(form, var) == 1.0
    @test ClF.getcursense(form, var) == ClF.Free
    @test ClF.getcurkind(form, var) == ClF.Integ
    @test ClF.getcurincval(form, var) == 4.0

    ClF.setcurcost!(form, var, 3.0)
    ClF.setcurlb!(form, var, -2.0)
    ClF.setcurub!(form, var, 2.0)
    ClF.setcurkind!(form, var, ClF.Continuous)
    ClF.setcurincval!(form, var, 3.0)

    @test ClF.getcurcost(form, var) == 3.0
    @test ClF.getcurlb(form, var) == -2.0
    @test ClF.getcurub(form, var) == 2.0
    @test ClF.getcursense(form, var) == ClF.Free
    @test ClF.getcurkind(form, var) == ClF.Continuous
    @test ClF.getcurincval(form, var) == 3.0

    ClF.reset!(form, var)
    @test ClF.getcurcost(form, var) == 2.0
    @test ClF.getcurlb(form, var) == -1.0
    @test ClF.getcurub(form, var) == 1.0
    @test ClF.getcursense(form, var) == ClF.Free
    @test ClF.getcurkind(form, var) == ClF.Integ
    @test ClF.getcurincval(form, var) == 4.0
    return
end
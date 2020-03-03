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
        sense = ClF.Positive, kind = ClF.Integ, inc_val = 4.0
    )

    @test ClF.getperenecost(form, var) == 2.0
    @test ClF.getperenelb(form, var) == -1.0
    @test ClF.getpereneub(form, var) == 1.0
    @test ClF.getperenesense(form, var) == ClF.Positive
    @test ClF.getperenekind(form, var) == ClF.Integ
    @test ClF.getpereneincval(form, var) == 4.0

    @test ClF.getcurcost(form, var) == 2.0
    @test ClF.getcurlb(form, var) == -1.0
    @test ClF.getcurub(form, var) == 1.0
    @test ClF.getcursense(form, var) == ClF.Positive
    @test ClF.getcurkind(form, var) == ClF.Integ
    @test ClF.getcurincval(form, var) == 4.0

    ClF.setcurcost!(form, var, 3.0)
    ClF.setcurlb!(form, var, -2.0)
    ClF.setcurub!(form, var, 2.0)
    ClF.setcursense!(form, var, ClF.Negative)
    ClF.setcurkind!(form, var, ClF.Continuous)
    ClF.setcurincval!(form, var, 3.0)

    @test ClF.getcurcost(form, var) == 3.0
    @test ClF.getcurlb(form, var) == -2.0
    @test ClF.getcurub(form, var) == 2.0
    @test ClF.getcursense(form, var) == ClF.Negative
    @test ClF.getcurkind(form, var) == ClF.Continuous
    @test ClF.getcurincval(form, var) == 3.0

    ClF.reset!(form, var)
    @test ClF.getcurcost(form, var) == 2.0
    @test ClF.getcurlb(form, var) == -1.0
    @test ClF.getcurub(form, var) == 1.0
    @test ClF.getcursense(form, var) == ClF.Positive
    @test ClF.getcurkind(form, var) == ClF.Integ
    @test ClF.getcurincval(form, var) == 4.0
    return
end
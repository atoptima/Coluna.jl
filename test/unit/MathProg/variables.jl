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
        form, "var1", ClF.OriginalVar, cost = 2.0, lb = -1.0, ub = 1.0
    )

    @test ClF.getperenecost(form, var) == 2.0
    @test ClF.getperenelb(form, var) == -1.0
    @test ClF.getpereneub(form, var) == 1.0

    @test ClF.getcurcost(form, var) == 2.0
    @test ClF.getcurlb(form, var) == -1.0
    @test ClF.getcurub(form, var) == 1.0

    ClF.setcurcost!(form, var, 3.0)
    ClF.setcurlb!(form, var, -2.0)
    ClF.setcurub!(form, var, 2.0)

    @test ClF.getcurcost(form, var) == 3.0
    @test ClF.getcurlb(form, var) == -2.0
    @test ClF.getcurub(form, var) == 2.0

    ClF.reset!(form, var)
    @test ClF.getcurcost(form, var) == 2.0
    @test ClF.getcurlb(form, var) == -1.0
    @test ClF.getcurub(form, var) == 1.0
    return
end
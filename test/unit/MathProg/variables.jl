function variables_unit_tests()
    getset_variables()
end

function createformulation()
    counter = ClF.Counter()
    return ClF.Formulation{ClF.Original}(counter)
end

function getset_variables()
    form = createformulation()
    var = ClF.setvar!(form, "var1", ClF.OriginalVar, cost = 2.0)
    @show form

    @test ClF.getcurcost(form, var) == 2.0
end
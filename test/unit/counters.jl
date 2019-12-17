function counters_unit_tests()
    counter_builder_n_getnewuid()
end

function counter_builder_n_getnewuid()
    c = ClF.Counter()
    @test c.value == 0
    @test ClF.getnewuid(c) == 1
end

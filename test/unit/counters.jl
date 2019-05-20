function counters_unit_tests()
    counter_builder_n_getnewuid()
end

function counter_builder_n_getnewuid()
    c = CL.Counter()
    @test c.value == 0
    @test CL.getnewuid(c) == 1
end

function strategy_unit_tests()
    strategy_record_get_n_set()
    strategy_fallbacks_tests()
end

function strategy_record_get_n_set()
    r = CL.StrategyRecord()
    CL.setalgorithm!(r, CL.FullColumnGeneration)
    @test CL.getalgorithm(r) == CL.FullColumnGeneration
end

function strategy_fallbacks_tests()
    @test_throws ErrorException CL.apply!(CL.AbstractStrategy)
end

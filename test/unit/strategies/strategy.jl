function strategy_unit_tests()
    strategy_record_get_n_set()
    strategy_fallbacks_tests()
end

function strategy_record_get_n_set()
    r = CL.StrategyRecord()
    CL.setsolver!(r, CL.ColumnGeneration)
    @test CL.getsolver(r) == CL.ColumnGeneration
end

function strategy_fallbacks_tests()
    @test_throws ErrorException CL.apply!(CL.AbstractStrategy)
end

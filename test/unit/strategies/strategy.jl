function strategy_unit_tests()
    strategy_fallbacks_tests()
end

function strategy_fallbacks_tests()
    @test_throws ErrorException CL.apply!(CL.AbstractStrategy)
end

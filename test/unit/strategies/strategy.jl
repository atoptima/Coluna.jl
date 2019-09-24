function strategy_unit_tests()
    strategy_fallbacks_tests()
end

struct UnknownStrategy <: CL.AbstractStrategy end

function strategy_fallbacks_tests()
    @test_throws ErrorException CL.apply!(UnknownStrategy())
end

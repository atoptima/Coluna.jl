function strategy_unit_tests()
    strategy_fallbacks_tests()
end

struct UnknownStrategy <: ClA.AbstractStrategy end

function strategy_fallbacks_tests()
    @test_throws ErrorException ClA.apply!(UnknownStrategy())
end

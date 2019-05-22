function algorithm_unit_tests()
    algorithm_fallbacks_tests()
end

function algorithm_fallbacks_tests()
    @test_throws ErrorException CL.prepare!(CL.AbstractAlgorithm, nothing, nothing, nothing, nothing)
    @test_throws ErrorException CL.run!(CL.AbstractAlgorithm, nothing, nothing, nothing, nothing)
end

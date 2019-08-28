function optimizationresults_unit_test()
    emptyresults_tests()
end

function emptyresults_tests()
    result = CL.OptimizationResult{CL.MinSense}()
    @test CL.getprimalbound(result) == Inf
    @test CL.getdualbound(result) == -Inf
    @test CL.getbestprimalsol(result) == nothing
    @test CL.getbestdualsol(result) == nothing
end
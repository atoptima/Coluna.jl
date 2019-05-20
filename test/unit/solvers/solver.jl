function solver_unit_tests()
    solver_fallbacks_tests()
end

function solver_fallbacks_tests()
    @test_throws ErrorException CL.prepare!(CL.AbstractSolver, nothing, nothing, nothing, nothing)
    @test_throws ErrorException CL.run!(CL.AbstractSolver, nothing, nothing, nothing, nothing)
end

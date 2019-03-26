function mastercolumn_unit_tests()
    mastercolumn_tests()
end

function mastercolumn_tests()
    vc_counter = CL.VarConstrCounter(0)
    sol = CL.PrimalSolution(0.0, Dict{CL.Variable,Float64}())
    mc = CL.MasterColumn(vc_counter, sol)
    @test mc.solution == sol
end

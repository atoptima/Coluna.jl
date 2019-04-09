function vcids_unit_tests()
    id_unit_tests()
end

function id_unit_tests()
    var = CL.Variable(1, "variable", 9.0, -1.0, 10.0, CL.Integ, CL.Free)
    i = CL.Id(1, CL.OriginalVar, var)

    @test CL.getuid(i) == 1
    
    state = CL.getstate(i)
    @test CL.getduty(state) == CL.OriginalVar
    @test CL.getcost(state) == CL.getcost(var)
    @test CL.getlb(state) == CL.getlb(var)
    @test CL.getub(state) == CL.getub(var)
    @test CL.getkind(state) == CL.getkind(var)
    @test CL.getstatus(state) == CL.Active
    return
end
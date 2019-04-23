function vcids_unit_tests()
   # id_unit_tests()
end

function id_unit_tests()
    var = CL.Variable(1, "variable", 9.0, -1.0, 10.0, CL.Integ, CL.Free)
    i = CL.Id(1, CL.OriginalVar, var)

    @test CL.get_uid(i) == 1
    
    state = CL.getstate(i)
    @test CL.get_duty(state) == CL.OriginalVar
    @test CL.get_cost(state) == CL.get_cost(var)
    @test CL.get_lb(state) == CL.get_lb(var)
    @test CL.get_ub(state) == CL.get_ub(var)
    @test CL.get_kind(state) == CL.get_kind(var)
    @test CL.getstatus(state) == CL.Active
    return
end

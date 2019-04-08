function constraint_unit_tests()
    # A method to test each method
    constraint_getters_setters_unit_tests()
    constraint_set!_unit_tests()
    constrstate_getters_setters_unit_tests()
end

function constraint_getters_setters_unit_tests()
    constr = CL.Constraint(0, "constr", 0.0, CL.Greater, CL.Core)
    @test CL.getform(constr) == 0
    @test CL.getname(constr) == "constr"
    @test CL.getrhs(constr) == 0.0
    @test CL.getkind(constr) == CL.Core

    @test CL.setform!(constr, 1) == 1
    @test CL.getform(constr) == 1
    @test CL.setname!(constr, "rtsnoc") == "rtsnoc"
    @test CL.getname(constr) == "rtsnoc"
    @test CL.setrhs!(constr, 2.0) == 2.0
    @test CL.getrhs(constr) == 2.0
    @test CL.setsense!(constr, CL.Less) == CL.Less
    @test CL.getsense(constr) == CL.Less
    @test CL.setkind!(constr, CL.Facultative) == CL.Facultative
    @test CL.getkind(constr) == CL.Facultative
    return
end

function constraint_set!_unit_tests()
    constr = CL.Constraint(0, "constr", 0.0,  CL.Greater, CL.Core)
    CL.set!(constr, MOI.LessThan{Float64}(100.0))
    @test CL.getrhs(constr) == 100.0
    @test CL.getsense(constr) == CL.Less

    CL.set!(constr, MOI.EqualTo{Float64}(10.0))
    @test CL.getrhs(constr) == 10.0
    @test CL.getsense(constr) == CL.Equal

    CL.set!(constr, MOI.GreaterThan{Float64}(0.0))
    @test CL.getrhs(constr) == 0.0
    @test CL.getsense(constr) == CL.Greater
end

function constrstate_getters_setters_unit_tests()
    # TODO : state should be immutable ?    
end
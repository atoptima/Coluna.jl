function constraint_unit_tests()
    # A method to test each method
    #constraint_getters_setters_unit_tests()
   # constraint_set!_unit_tests()
   # constrstate_getters_setters_unit_tests()
end

function constraint_getters_setters_unit_tests()
    constr = CL.Constraint(0, "constr", 0.0, CL.Greater, CL.Core)
    @test CL.get_form(constr) == 0
    @test CL.get_name(constr) == "constr"
    @test CL.get_rhs(constr) == 0.0
    @test CL.get_kind(constr) == CL.Core

    @test CL.setform!(constr, 1) == 1
    @test CL.get_form(constr) == 1
    #@test CL.setname!(constr, "rtsnoc") == "rtsnoc"
    @test CL.get_name(constr) == "rtsnoc"
    @test CL.set_rhs!(constr, 2.0) == 2.0
    @test CL.get_rhs(constr) == 2.0
    @test CL.set_sense!(constr, CL.Less) == CL.Less
    @test CL.get_sense(constr) == CL.Less
    @test CL.set_kind!(constr, CL.Facultative) == CL.Facultative
    @test CL.get_kind(constr) == CL.Facultative
    return
end

function constraint_set!_unit_tests()
    constr = CL.Constraint(0, "constr", 0.0,  CL.Greater, CL.Core)
    CL.set!(constr, MOI.LessThan{Float64}(100.0))
    @test CL.get_rhs(constr) == 100.0
    @test CL.get_sense(constr) == CL.Less

    CL.set!(constr, MOI.EqualTo{Float64}(10.0))
    @test CL.get_rhs(constr) == 10.0
    @test CL.get_sense(constr) == CL.Equal

    CL.set!(constr, MOI.GreaterThan{Float64}(0.0))
    @test CL.get_rhs(constr) == 0.0
    @test CL.get_sense(constr) == CL.Greater
end

function constrstate_getters_setters_unit_tests()
    # TODO : state should be immutable ?    
end

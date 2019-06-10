function vcids_unit_tests()
   id_unit_tests()
end

function id_unit_tests()

    var_id = CL.Id{CL.Variable}(20, 13)
    @test CL.getuid(var_id) == 20
    @test CL.getformuid(var_id) == 13
    @test CL.getprocuid(var_id) == 1
    @test var_id._hash == 2013011
    @test isequal(var_id, 2013011)
    @test isequal(2013011, var_id)

    constr_id = CL.Id{CL.Constraint}(100, 3)
    @test CL.getuid(constr_id) == 100
    @test CL.getformuid(constr_id) == 3
    @test CL.getprocuid(constr_id) == 1
    @test constr_id._hash == 10003011
    @test isequal(constr_id, 10003011)
    @test isequal(10003011, constr_id)

    @test var_id < constr_id
    #@test CL.getsortid(constr_id) == 100 + 1000000 * 3

    return
end

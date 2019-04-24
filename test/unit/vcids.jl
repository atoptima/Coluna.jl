function vcids_unit_tests()
   id_unit_tests()
end

function id_unit_tests()

    var_id = CL.Id{CL.Variable}(20, 13)
    @test CL.get_uid(var_id) == 20
    @test CL.getformuid(var_id) == 13
    @test CL.getprocuid(var_id) == 1
    @test var_id._hash == 201301
    @test isequal(var_id, 201301)
    @test isequal(201301, var_id)

    constr_id = CL.Id{CL.Constraint}(100, 3)
    @test CL.get_uid(constr_id) == 100
    @test CL.getformuid(constr_id) == 3
    @test CL.getprocuid(constr_id) == 1
    @test constr_id._hash == 1000301
    @test isequal(constr_id, 1000301)
    @test isequal(1000301, constr_id)

    return
end

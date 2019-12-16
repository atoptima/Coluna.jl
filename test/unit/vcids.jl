function vcids_unit_tests()
   id_unit_tests()
end

function id_unit_tests()

    var_id = ClF.Id{ClF.Variable}(20, 13)
    @test ClF.getuid(var_id) == 20
    @test ClF.getoriginformuid(var_id) == 13
    @test ClF.getprocuid(var_id) == 1
    @test var_id._hash == 201301
    @test isequal(var_id, 201301)
    @test isequal(201301, var_id)

    constr_id = ClF.Id{ClF.Constraint}(100, 3)
    @test ClF.getuid(constr_id) == 100
    @test ClF.getoriginformuid(constr_id) == 3
    @test ClF.getprocuid(constr_id) == 1
    @test constr_id._hash == 1000301
    @test isequal(constr_id, 1000301)
    @test isequal(1000301, constr_id)

    @test var_id < constr_id
    @test ClF.getsortuid(constr_id) == 100 + 1000000 * 3
    return
end

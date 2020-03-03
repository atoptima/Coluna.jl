function vcids_unit_tests()
   id_unit_tests()
end

function id_unit_tests()

    # varid = ClF.Id{ClF.Variable}(20, 13)
    # @test ClF.getuid(varid) == 20
    # @test ClF.getoriginformuid(varid) == 13
    # @test ClF.getprocuid(varid) == 1
    # @test varid._hash == 201301
    # @test isequal(varid, 201301)
    # @test isequal(201301, varid)

    # constrid = ClF.Id{ClF.Constraint}(100, 3)
    # @test ClF.getuid(constrid) == 100
    # @test ClF.getoriginformuid(constrid) == 3
    # @test ClF.getprocuid(constrid) == 1
    # @test constrid._hash == 1000301
    # @test isequal(constrid, 1000301)
    # @test isequal(1000301, constrid)

    # @test varid < constrid
    # @test ClF.getsortuid(constrid) == 100 + 1000000 * 3
    return
end

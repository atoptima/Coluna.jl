function vcdict_unit_tests()
    vcdict_base_unit_tests()
end

function vcdict_base_unit_tests()
    dict = CL.PerIdDict{CL.VarState, Float64}()
    var1 = CL.Variable("var1")
    var2 = CL.Variable("var2")
    id1 = CL.Id(1, CL.OriginalVar, var1)
    id2 = CL.Id(2, CL.MasterCol, var2)
    id3 = CL.Id(3, CL.OriginalVar, var1)
    id4 = CL.Id(1, CL.MasterCol, var1)

    @test length(dict) == 0
    dict[id1] = 0.0
    dict[id2] = 1.0
    @test length(dict) == 2
    @test haskey(dict, id1)
    @test haskey(dict, id2)
    @test dict[id1] == get(dict, id1, 1000)
    @test getkey(dict, id3, 1000) == 1000
    @test getkey(dict, id2, 1000) == id2
    @test dict[id1] == dict[id4] # same uid

    delete!(dict, id1)
    delete!(dict, id2)
    @test length(dict) == 0
    dict[id3] = 0.0
    dict[id4] = 1.0
    dict[id1] = 2.0 # should overwrite dict[id4]
    sum_vals = 0.0
    nb_iter = 0
    for (id, val) in dict
        sum_vals += val
        nb_iter += 1
    end
    @test sum_vals == 2.0
    @test nb_iter == 2
end
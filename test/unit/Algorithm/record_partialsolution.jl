function unit_partial_solution_record()
    env = CL.Env{ClMP.VarId}(CL.Params())

    # Create the following formulation:
    # min  1*v1 + 2*v2 + 4*v3
    #  c1: 2*v1 +          v3  >= 4
    #  c2:   v1 + 2*v2         >= 5
    #  c3:   v1 +   v2  +  v3  >= 3
    #        0 <= v1 <= 20 
    #      -10 <= v2 <= 10 
    #      -20 <= v3 <= 0 

    form = ClMP.create_formulation!(env, ClMP.DwMaster())
    vars = Dict{String,ClMP.Variable}()
    constrs = Dict{String,ClMP.Constraint}()

    rhs = [4,5,3]
    for i in 1:3
        c = ClMP.setconstr!(form, "c$i", ClMP.OriginalConstr; rhs = rhs[i], sense = ClMP.Less)
        constrs["c$i"] = c
    end

    members = [
        Dict(ClMP.getid(constrs["c1"]) => 2.0, ClMP.getid(constrs["c2"]) => 1.0, ClMP.getid(constrs["c3"]) => 1.0),
        Dict(ClMP.getid(constrs["c2"]) => 2.0, ClMP.getid(constrs["c3"]) => 1.0),
        Dict(ClMP.getid(constrs["c1"]) => 1.0, ClMP.getid(constrs["c3"]) => 1.0),
    ] 
    costs = [1,2,4]
    ubounds = [20,10,0]
    lbounds = [0,-10,-20]
    for i in 1:3
        v = ClMP.setvar!(form, "v$i", ClMP.OriginalVar; cost = costs[i], members = members[i], lb = lbounds[i], ub = ubounds[i])
        vars["v$i"] = v
    end
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    storage = ClB.getstorage(form)
    r1 = ClB.create_record(storage, ClA.PartialSolutionUnit)

    @test isempty(r1.partial_solution)

    # make changes on the formulation
    ClMP.add_to_partial_solution!(form, vars["v1"], 5.0, true) # we propagate to bounds
    ClMP.add_to_partial_solution!(form, vars["v2"], -1.0, true)
    ClMP.add_to_partial_solution!(form, vars["v3"], -2.0, true)

    @test ClMP.get_value_in_partial_sol(form, vars["v1"]) == 5
    @test ClMP.get_value_in_partial_sol(form, vars["v2"]) == -1
    @test ClMP.get_value_in_partial_sol(form, vars["v3"]) == -2
    @test ClMP.getcurlb(form, vars["v1"]) == 0
    @test ClMP.getcurlb(form, vars["v2"]) == -9
    @test ClMP.getcurlb(form, vars["v3"]) == -18
    @test ClMP.getcurub(form, vars["v1"]) == 15
    @test ClMP.getcurub(form, vars["v2"]) == 0
    @test ClMP.getcurub(form, vars["v3"]) == 0
    @test ClMP.in_partial_sol(form, vars["v1"])
    @test ClMP.in_partial_sol(form, vars["v2"])
    @test ClMP.in_partial_sol(form, vars["v3"])

    r2 = ClB.create_record(storage, ClA.PartialSolutionUnit)

    @test isempty(setdiff(keys(r2.partial_solution), ClMP.getid.(values(vars))))
    @test r2.partial_solution[ClMP.getid(vars["v1"])] == 5.0
    @test r2.partial_solution[ClMP.getid(vars["v2"])] == -1.0
    @test r2.partial_solution[ClMP.getid(vars["v3"])] == -2.0

    ClB.restore_from_record!(storage, r1)

    @test !ClMP.in_partial_sol(form, vars["v1"])
    @test !ClMP.in_partial_sol(form, vars["v2"])
    @test !ClMP.in_partial_sol(form, vars["v3"])

    ClB.restore_from_record!(storage, r2)
    @test ClMP.get_value_in_partial_sol(form, vars["v1"]) == 5.0
    @test ClMP.get_value_in_partial_sol(form, vars["v2"]) == -1.0
    @test ClMP.get_value_in_partial_sol(form, vars["v3"]) == -2.0
end
register!(unit_tests, "storage_record", unit_partial_solution_record)
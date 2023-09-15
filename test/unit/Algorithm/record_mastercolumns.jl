function unit_master_columns_record()
    function test_record(state, cost, lb, ub, fixed)
        @test state.cost == cost
        @test state.lb == lb
        @test state.ub == ub
        #@test state.fixed == fixed
    end

    function test_var(form, var, cost, lb, ub, fixed)
        @test ClMP.getcurcost(form, var) == cost
        @test ClMP.getcurlb(form, var) == lb
        @test ClMP.getcurub(form, var) == ub
        #@test ClMP.isfixed(form, var) == fixed
    end

    env = CL.Env{ClMP.VarId}(CL.Params())

    # Create the following formulation:
    # min  1*v1 + 2*v2 + 4*v3
    #  c1: 2*v1 +          v3  >= 4
    #  c2:   v1 + 2*v2         >= 5
    #  c3:   v1 +   v2  +  v3  >= 3 

    form = ClMP.create_formulation!(env, ClMP.DwMaster())
    vars = Dict{String,ClMP.Variable}()
    constrs = Dict{String,ClMP.Constraint}()

    rhs = [4,5,3]
    for i in 1:3
        c = ClMP.setconstr!(form, "c$i", ClMP.MasterMixedConstr; rhs = rhs[i], sense = ClMP.Less)
        constrs["c$i"] = c
    end

    members = [
        Dict(ClMP.getid(constrs["c1"]) => 2.0, ClMP.getid(constrs["c2"]) => 1.0, ClMP.getid(constrs["c3"]) => 1.0),
        Dict(ClMP.getid(constrs["c2"]) => 2.0, ClMP.getid(constrs["c3"]) => 1.0),
        Dict(ClMP.getid(constrs["c1"]) => 1.0, ClMP.getid(constrs["c3"]) => 1.0),
    ] 
    costs = [1,2,4]
    for i in 1:3
        v = ClMP.setvar!(form, "v$i", ClMP.MasterCol; cost = costs[i], members = members[i], lb = 0)
        vars["v$i"] = v
    end
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    storage = ClB.getstorage(form)
    r1 = ClB.create_record(storage, ClA.MasterColumnsUnit)

    @test isempty(setdiff(keys(r1.cols), ClMP.getid.(values(vars))))
    test_record(r1.cols[ClMP.getid(vars["v1"])], 1, 0, Inf, false)
    test_record(r1.cols[ClMP.getid(vars["v2"])], 2, 0, Inf, false)
    test_record(r1.cols[ClMP.getid(vars["v3"])], 4, 0, Inf, false)

    # make changes on the formulation
    ClMP.setcurlb!(form, vars["v1"], 5.0)
    ClMP.setcurub!(form, vars["v2"], 12.0)
    ClMP.setcurcost!(form, vars["v3"], 4.6)
    #ClMP.fix!(form, vars["v3"], 3.5)

    r2 = ClB.create_record(storage, ClA.MasterColumnsUnit)

    @test isempty(setdiff(keys(r2.cols), ClMP.getid.(values(vars))))
    test_record(r2.cols[ClMP.getid(vars["v1"])], 1, 5, Inf, false)
    test_record(r2.cols[ClMP.getid(vars["v2"])], 2, 0, 12, false)
    #test_record(r2.cols[ClMP.getid(vars["v3"])], 4.6, 3.5, 3.5, true)
    test_record(r2.cols[ClMP.getid(vars["v3"])], 4.6, 0, Inf, false)

    ClB.restore_from_record!(storage, r1)

    test_var(form, vars["v1"], 1, 0, Inf, false)
    test_var(form, vars["v2"], 2, 0, Inf, false)
    test_var(form, vars["v3"], 4, 0, Inf, false)

    ClB.restore_from_record!(storage, r2)

    test_var(form, vars["v1"], 1, 5, Inf, false)
    test_var(form, vars["v2"], 2, 0, 12, false)
    #test_var(form, vars["v3"], 4.6, 3.5, 3.5, true)
    test_var(form, vars["v3"], 4.6, 0, Inf, false)
end
register!(unit_tests, "master_columns_record", unit_master_columns_record)
function unit_static_var_constr_record1()
    function test_var_record(state, cost, lb, ub, partial_sol_value)
        @test state.cost == cost
        @test state.lb == lb
        @test state.ub == ub
        @test state.partial_sol_value == partial_sol_value
    end

    function test_var(form, var, cost, lb, ub, partial_sol_value)
        @test ClMP.getcurcost(form, var) == cost
        @test ClMP.getcurlb(form, var) == lb
        @test ClMP.getcurub(form, var) == ub
        @test ClMP.get_value_in_partial_sol(form, var) == partial_sol_value
    end

    function test_constr_record(state, rhs)
        @test state.rhs == rhs
    end

    function test_constr(form, constr, rhs)
        @test ClMP.getcurrhs(form, constr) == rhs
    end

    env = CL.Env{ClMP.VarId}(CL.Params())

    # Create the following formulation:
    # min  1*v1 + 2*v2 + 4*v3
    #  c1: 2*v1 +          v3  >= 4
    #  c2:   v1 + 2*v2         >= 5
    #  c3:   v1 +   v2  +  v3  >= 3
    #        0 <= v1 <= 10 
    #        0 <= v2 <= 20 
    #        0 <= v3 <= 30 

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
    ubounds = [10,20,30]
    for i in 1:3
        v = ClMP.setvar!(form, "v$i", ClMP.OriginalVar; cost = costs[i], members = members[i], lb = 0, ub = ubounds[i])
        vars["v$i"] = v
    end
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    storage = ClB.getstorage(form)
    r1 = ClB.create_record(storage, ClA.StaticVarConstrUnit)

    @test isempty(setdiff(keys(r1.vars), ClMP.getid.(values(vars))))
    @test isempty(setdiff(keys(r1.constrs), ClMP.getid.(values(constrs))))
    test_var_record(r1.vars[ClMP.getid(vars["v1"])], 1, 0, 10, 0)
    test_var_record(r1.vars[ClMP.getid(vars["v2"])], 2, 0, 20, 0)
    test_var_record(r1.vars[ClMP.getid(vars["v3"])], 4, 0, 30, 0)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c1"])], 4)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c2"])], 5)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c3"])], 3)

    # make changes on the formulation
    ClMP.setcurlb!(form, vars["v1"], 5.0)
    ClMP.setcurub!(form, vars["v2"], 12.0)
    ClMP.setcurcost!(form, vars["v3"], 4.6)
    ClMP.setcurrhs!(form, constrs["c1"], 1.0)
    ClMP.deactivate!(form, constrs["c2"])

    r2 = ClB.create_record(storage, ClA.StaticVarConstrUnit)

    @test isempty(setdiff(keys(r2.vars), ClMP.getid.(values(vars))))
    @test length(r2.constrs) == 2
    test_var_record(r2.vars[ClMP.getid(vars["v1"])], 1, 5, 10, 0)
    test_var_record(r2.vars[ClMP.getid(vars["v2"])], 2, 0, 12, 0)
    test_var_record(r2.vars[ClMP.getid(vars["v3"])], 4.6, 0, 30, 0)
    test_constr_record(r2.constrs[ClMP.getid(constrs["c1"])], 1)
    test_constr_record(r2.constrs[ClMP.getid(constrs["c3"])], 3)

    ClB.restore_from_record!(storage, r1)

    test_var(form, vars["v1"], 1, 0, 10, 0)
    test_var(form, vars["v2"], 2, 0, 20, 0)
    test_var(form, vars["v3"], 4, 0, 30, 0)
    test_constr(form, constrs["c1"], 4)
    @test ClMP.iscuractive(form, constrs["c2"])

    ClB.restore_from_record!(storage, r2)

    test_var(form, vars["v1"], 1, 5, 10, 0)
    test_var(form, vars["v2"], 2, 0, 12, 0)
    test_var(form, vars["v3"], 4.6, 0, 30, 0)
    test_constr(form, constrs["c1"], 1)
    @test !ClMP.iscuractive(form, constrs["c2"])
end
register!(unit_tests, "master_columns_record", unit_static_var_constr_record1)

# Partial solution.
function unit_static_var_constr_record2()
    function test_var_record(state, cost, lb, ub, partial_sol_value)
        @test state.cost == cost
        @test state.lb == lb
        @test state.ub == ub
        @test state.partial_sol_value == partial_sol_value
    end

    function test_var(form, var, cost, lb, ub, partial_sol_value)
        @test ClMP.getcurcost(form, var) == cost
        @test ClMP.getcurlb(form, var) == lb
        @test ClMP.getcurub(form, var) == ub
        @test ClMP.get_value_in_partial_sol(form, var) == partial_sol_value
    end

    function test_constr_record(state, rhs)
        @test state.rhs == rhs
    end

    function test_constr(form, constr, rhs)
        @test ClMP.getcurrhs(form, constr) == rhs
    end

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
    r1 = ClB.create_record(storage, ClA.StaticVarConstrUnit)

    @test isempty(setdiff(keys(r1.vars), ClMP.getid.(values(vars))))
    @test isempty(setdiff(keys(r1.constrs), ClMP.getid.(values(constrs))))
    test_var_record(r1.vars[ClMP.getid(vars["v1"])], 1,   0, 20, 0)
    test_var_record(r1.vars[ClMP.getid(vars["v2"])], 2, -10, 10, 0)
    test_var_record(r1.vars[ClMP.getid(vars["v3"])], 4, -20,  0, 0)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c1"])], 4)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c2"])], 5)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c3"])], 3)

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

    r2 = ClB.create_record(storage, ClA.StaticVarConstrUnit)

    @test isempty(setdiff(keys(r2.vars), ClMP.getid.(values(vars))))
    test_var_record(r2.vars[ClMP.getid(vars["v1"])], 1, 0, 15, 5)
    test_var_record(r2.vars[ClMP.getid(vars["v2"])], 2, -9, 0, -1)
    test_var_record(r2.vars[ClMP.getid(vars["v3"])], 4, -18, 0, -2)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c1"])], 4)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c2"])], 5)
    test_constr_record(r1.constrs[ClMP.getid(constrs["c3"])], 3)

    ClB.restore_from_record!(storage, r1)

    test_var(form, vars["v1"], 1, 0, 20, 0)
    test_var(form, vars["v2"], 2, -10, 10, 0)
    test_var(form, vars["v3"], 4, -20, 0, 0)
    test_constr(form, constrs["c1"], 4)
    test_constr(form, constrs["c2"], 5)
    test_constr(form, constrs["c3"], 3)
    @test !ClMP.in_partial_sol(form, vars["v1"])
    @test !ClMP.in_partial_sol(form, vars["v2"])
    @test !ClMP.in_partial_sol(form, vars["v3"])

    ClB.restore_from_record!(storage, r2)

    test_var(form, vars["v1"], 1, 0, 15, 5)
    test_var(form, vars["v2"], 2, -9, 0, -1)
    test_var(form, vars["v3"], 4, -18, 0, -2)
    test_constr(form, constrs["c1"], 4)
    test_constr(form, constrs["c2"], 5)
    test_constr(form, constrs["c3"], 3)
    @test ClMP.in_partial_sol(form, vars["v1"])
    @test ClMP.in_partial_sol(form, vars["v2"])
    @test ClMP.in_partial_sol(form, vars["v3"])
end
register!(unit_tests, "master_columns_record", unit_static_var_constr_record2)
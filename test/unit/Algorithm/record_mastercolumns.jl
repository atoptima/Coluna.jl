function unit_master_columns_record()

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

    @test isempty(setdiff(r1.active_cols, ClMP.getid.(values(vars))))

    # make changes on the formulation
    ClMP.deactivate!(form, vars["v2"])

    r2 = ClB.create_record(storage, ClA.MasterColumnsUnit)

    v1v3 = Set{ClMP.VarId}([ClMP.getid(vars["v1"]), ClMP.getid(vars["v3"])])
    @test isempty(setdiff(r2.active_cols, v1v3))

    ClB.restore_from_record!(storage, r1)
    active_varids = filter(var_id -> iscuractive(form, var_id), keys(ClMP.getvars(form)))
    @test isempty(setdiff(active_varids, ClMP.getid.(values(vars))))

    ClB.restore_from_record!(storage, r2)
    active_varids = filter(var_id -> iscuractive(form, var_id), keys(ClMP.getvars(form)))
    @test isempty(setdiff(active_varids, v1v3))
end
register!(unit_tests, "storage_record", unit_master_columns_record)
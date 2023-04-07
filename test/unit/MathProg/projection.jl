function test_mapping_operator_1()
    G = Vector{Float64}[
        [0, 0, 1, 1, 0, 0, 1],
        [1, 0, 0, 1, 1, 0, 1],
        [1, 1, 0, 0, 1, 1, 0],
        [0, 1, 1, 0, 0, 1, 1]
    ]

    v = Float64[3, 2, 0, 0]

    result = Coluna.MathProg._mapping(G, v; col_len = 7)#, 6)
    @test result == [
        [1, 0, 0, 1, 1, 0, 1],
        [1, 0, 0, 1, 1, 0, 1],
        [0, 0, 1, 1, 0, 0, 1],
        [0, 0, 1, 1, 0, 0, 1],
        [0, 0, 1, 1, 0, 0, 1],
    ]
end
register!(unit_tests, "projection", test_mapping_operator_1; f= true)

function test_mapping_operator_2()
    # Example from the paper:
    # Branching in Branch-and-Price: a Generic Scheme
    # François Vanderbeck

    # A = [
    #     1 0 1 0;
    #     0 1 0 1;
    #     1 1 0 2;
    # ]
    # a = [5 5 10]

    G = Vector{Float64}[
        [1, 1, 1, 0],
        [1, 1, 0, 1],
        [1, 1, 0, 0],
        [1, 0, 1, 1],
        [1, 0, 1, 0],
        [1, 0, 0, 1],
        [1, 0, 0, 0],
        [0, 1, 1, 1],
        [0, 1, 1, 0],
        [0, 1, 0, 1],
        [0, 1, 0, 0],
        [0, 0, 1, 1],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
    ]

    v = Float64[0, 1/2, 1, 1/2, 0, 0, 1, 1, 0, 0, 1/2, 0, 1/2, 0, 0]

    result = Coluna.MathProg._mapping(G, v; col_len = 4)
end
register!(unit_tests, "projection", test_mapping_operator_2; f=true)

# function test_mapping_operator_3()
#     G = Vector{Float64}[
#         #x_12, x_13, x_14, x_15, x_23, x_24, x_25, x_34, x_35, x_45
#         [1,    0,    1,    0,    0,    1,    0,    0,   0,    0],
#         [1,    0,    0,    1,    1,    0,    0,    0,   1,    0],
#         [0,    1,    1,    0,    0,    0,    0,    1,   0,    0],
#         [0,    0,    0,    2,    0,    0,    0,    0,   0,    0],
#         [1,    0,    1,    0,    1,    0,    0,    1,   0,    0],
#         [0,    1,    0,    1,    0,    0,    0,    0,   1,    0]
#     ]

#     v = Float64[2/3, 1/3, 1/3, 2/3, 1/3, 1/3]

#     result = Coluna.MathProg._mapping(G, v, 10)
#     @show result

# end
# register!(unit_tests, "projection", test_mapping_operator_3; f= true)

function identical_subproblems_vrp()
    # We consider a vrp problem (with fake subproblem) where routes are:
    # - MC1 : 1 -> 2 -> 3  
    # - MC2 : 2 -> 3 -> 4  
    # - MC4 : 3 -> 4 -> 1  
    # - MC3 : 4 -> 1 -> 2
    # At most, three vehicles are available to visit all customers.
    # We can visit a customer multiple times.
    # Fractional solution is 1/2 for all columns
    form = """
    master
        min
        x_12 + x_13 + x_14 + x_23 + x_24 + x_34 + MC1 + MC2 + MC3 + MC4 + 0.0 PricingSetupVar_sp_5 
        s.t.
        x_12 + x_13 + x_14 + MC1       + MC3 + MC4 >= 1.0
        x_12 + x_23 + x_24 + MC1 + MC2       + MC4 >= 1.0
        x_13 + x_23 + x_34 + MC1 + MC2 + MC3       >= 1.0
        x_14 + x_24 + x_34       + MC2 + MC3 + MC4 >= 1.0
        PricingSetupVar_sp_5 >= 0.0 {MasterConvexityConstr}
        PricingSetupVar_sp_5 <= 3.0 {MasterConvexityConstr}

    dw_sp
        min
        x_12 + x_13 + x_14 + x_23 + x_24 + x_34 + 0.0 PricingSetupVar_sp_5  
        s.t.
        x_12 + x_13 + x_14 + x_23 + x_24 + x_34 >= 0

    continuous
        columns
            MC1, MC2, MC3, MC4

    integer
        pricing_setup
            PricingSetupVar_sp_5

    binary
        representatives
            x_12, x_13, x_14, x_23, x_24, x_34
 
    bounds
        0.0 <= x_12 <= 1.0
        0.0 <= x_13 <= 1.0
        0.0 <= x_14 <= 1.0
        0.0 <= x_23 <= 1.0
        0.0 <= x_24 <= 1.0
        0.0 <= x_34 <= 1.0
        MC1 >= 0
        MC2 >= 0
        MC3 >= 0
        MC4 >= 0
        1.0 <= PricingSetupVar_sp_5 <= 1.0
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function projection_from_dw_reform_to_master_1()
    env, master, sps, reform = identical_subproblems_vrp()
    mastervarids = Dict(CL.getname(master, var) => varid for (varid, var) in CL.getvars(master))

    # Register column in the pool
    spform = first(sps)
    pool = ClMP.get_primal_sol_pool(spform)
    pool_hashtable = ClMP._get_primal_sol_pool_hash_table(spform)
    costs_pool = spform.duty_data.costs_primalsols_pool
    custom_pool = spform.duty_data.custom_primalsols_pool

    var_ids = map(n -> mastervarids[n], ["x_12", "x_13", "x_14", "x_23", "x_24", "x_34"])
    for (name, vals) in Iterators.zip(
            ["MC1", "MC2", "MC3", "MC4"],
            [
                [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 0.0, 1.0, 0.0, 1.0],
                [0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
                [1.0, 0.0, 1.0, 0.0, 0.0, 0.0]
            ]
    )
        col_id = ClMP.VarId(mastervarids[name]; duty = DwSpPrimalSol)
        addrow!(pool, col_id, var_ids, vals)
        costs_pool[col_id] = 1.0
        ClMP.savesolid!(pool_hashtable, col_id, ClMP.PrimalSolution(spform, var_ids, vals, 1.0, ClMP.FEASIBLE_SOL))
    end

    # Create primal solution where each route is used 1/2 time.
    # This solution is integer feasible.
    solution = Coluna.MathProg.PrimalSolution(
        master,
        map(n -> ClMP.VarId(mastervarids[n]; origin_form_uid = 2), ["MC1", "MC2", "MC3", "MC4"]),
        [1/2, 1/2, 1/2, 1/2],
        2.0,
        ClB.FEASIBLE_SOL
    )

    # Test integration
    columns, values = Coluna.MathProg._extract_data_for_mapping(solution)
    rolls = Coluna.MathProg._mapping_by_subproblem(columns, values)

    # Expected:
    # | 1/2 of [1.0, 0.0, 1.0, 0.0, 0.0, 0.0]
    # | 1/2 of [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    # ----->   [1.0, 0.0, 0.5, 0.5, 0.0, 0.0]
    # | 1/2 of [0.0, 0.0, 1.0, 0.0, 0.0, 1.0]
    # | 1/2 of [0.0, 0.0, 0.0, 1.0, 0.0, 1.0]
    # ----->   [0.0, 0.0, 0.5, 0.5, 0.0, 1.0]
    @test rolls == Dict(2 => [
        Dict(mastervarids["x_14"] => 0.5, mastervarids["x_23"] => 0.5, mastervarids["x_34"] => 1.0)
        Dict(mastervarids["x_12"] => 1.0, mastervarids["x_14"] => 0.5, mastervarids["x_23"] => 0.5)
    ])

    proj = Coluna.MathProg.proj_cols_on_rep(solution)
    @test proj[mastervarids["x_12"]] == 1.0
    @test proj[mastervarids["x_14"]] == 1.0
    @test proj[mastervarids["x_23"]] == 1.0
    @test proj[mastervarids["x_34"]] == 1.0

end
register!(unit_tests, "projection", projection_from_dw_reform_to_master_1; f = true)
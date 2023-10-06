function test_non_proper_column1()
    # min x1 + x2 + 1MC1 + 2MC2 + 4MC3
    # s.t. x1 + x2 + MC1 + MC2 + MC3 >= 2
    # 0 <= x1 <= 1
    # 0 <= x2 <= 2

    # with
    # MC1 = [x1 = 1]
    # MC2 = [x2 = 2]
    # MC3 = [x1 = 2, x2 = 2] # non-proper!

    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    master_form, master_name_to_var, master_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 2.0, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing),
            ("MC2", Coluna.MathProg.MasterCol, 2.0, 0.0, 1.0, nothing),
            ("MC3", Coluna.MathProg.MasterCol, 4.0, 0.0, 1.0, nothing),
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 2.0, ClMP.Greater, nothing),
        ]
    )

    coeffs = [
        # var, constr, coeff
        ("c1", "x1", 1.0),
        ("c1", "x2", 1.0),
        ("c1", "MC1", 1.0),
        ("c1", "MC2", 1.0),
        ("c1", "MC3", 1.0),
    ]
    
    master_form_coef_matrix = Coluna.MathProg.getcoefmatrix(master_form)
    for (constr_name, var_name, coef) in coeffs
        constr = master_name_to_constr[constr_name]
        var = master_name_to_var[var_name]
        master_form_coef_matrix[ClMP.getid(constr), ClMP.getid(var)] = coef
    end
    DynamicSparseArrays.closefillmode!(master_form_coef_matrix)
    

    sp_form, sp_name_to_var, sp_name_to_constr = _mathprog_formulation!(
        env, 
        Coluna.MathProg.DwSp(
            nothing, nothing, nothing, ClMP.Continuous, Coluna.MathProg.Pool()
        ),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x1"])),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 2.0, Coluna.Algorithm.getid(master_name_to_var["x2"]))
        ],
        [
            # name, duty, rhs, sense, id
            ("c2", Coluna.MathProg.DwSpPureConstr, 2.0, ClMP.Less, nothing)
        ],
    )

    var_ids = [Coluna.MathProg.getid(sp_name_to_var["x1"]), Coluna.MathProg.getid(sp_name_to_var["x2"])]
    pool = Coluna.MathProg.get_primal_sol_pool(sp_form)

    for (name, vals) in Iterators.zip(
        ["MC1", "MC2", "MC3"],
        [
            #x1, x2,
            Float64[1.0, 0.0],
            Float64[0.0, 1.0],
            Float64[2.0, 2.0]
        ]
    )
        col_id = Coluna.MathProg.VarId(Coluna.MathProg.getid(master_name_to_var[name]); duty = Coluna.MathProg.DwSpPrimalSol)
        Coluna.MathProg.push_in_pool!(
            pool,
            Coluna.MathProg.PrimalSolution(sp_form, var_ids, vals, 1.0, Coluna.MathProg.FEASIBLE_SOL),
            col_id,
            1.0
        )
    end

    @test Coluna.Algorithm._column_is_proper(Coluna.getid(master_name_to_var["MC1"]), sp_form) === true
    @test Coluna.Algorithm._column_is_proper(Coluna.getid(master_name_to_var["MC2"]), sp_form) === true
    @test Coluna.Algorithm._column_is_proper(Coluna.getid(master_name_to_var["MC3"]), sp_form) === false

    return
end
register!(unit_tests, "columns", test_non_proper_column1)
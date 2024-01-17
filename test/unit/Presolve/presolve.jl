function test_compute_rhs1()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    restricted_master, name_to_vars, name_to_constrs = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 2.0, nothing, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing, 2),
            ("MC2", Coluna.MathProg.MasterCol, 2.0, 1.0, 1.0, nothing, 2),
            ("MC3", Coluna.MathProg.MasterCol, 4.0, 2.0, 4.0, nothing, 2),
            ("y1", Coluna.MathProg.MasterPureVar, 5.0, 1.5, Inf, nothing, nothing),
            ("y2", Coluna.MathProg.MasterPureVar, 0.0, 2.5, Inf, nothing, nothing),
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 2.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.MasterConvexityConstr, 0.0, ClMP.Greater, nothing),
            ("c3", Coluna.MathProg.MasterConvexityConstr, 2.0, ClMP.Less, nothing)
        ]
    )

    master_repr_presolve_form = _presolve_formulation(
        ["MC1", "MC2", "MC3", "y1", "y2"],
        ["c1", "c2", "c3"],
        [1 1 3 2 2; 1 1 1 0 0; 1 1 1 0 0],
        restricted_master,
        name_to_vars,
        name_to_constrs,
    )
    
    partial_sol = [0.0, 0.0, 1.0, 1.0, 0.0]

    rhs_result = Coluna.Algorithm.compute_rhs(
        master_repr_presolve_form,
        partial_sol
    )

    @test rhs_result == [
        2.0 - 3 * 1.0 - 2 * 1.0, # MC3 & y1
        0.0 - 1.0,               # MC3
        2.0 - 1.0,               # MC3
    ]
end
register!(unit_tests, "presolve_algorithm", test_compute_rhs1)

function test_partial_sol_on_repr()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    master, master_name_to_var, master_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 2.0, nothing, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing, 2),
            ("MC2", Coluna.MathProg.MasterCol, 2.0, 1.0, 1.0, nothing, 2),
            ("MC3", Coluna.MathProg.MasterCol, 4.0, 2.0, 4.0, nothing, 2),
            ("y1", Coluna.MathProg.MasterPureVar, 5.0, 1.5, Inf, nothing, nothing),
            ("y2", Coluna.MathProg.MasterPureVar, 0.0, 2.5, Inf, nothing, nothing),
            ("pricing_setup", Coluna.MathProg.MasterRepPricingSetupVar, 0.0, 1.0, 1.0, nothing, nothing)
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.MasterConvexityConstr, 0.0, ClMP.Greater, nothing),
            ("c3", Coluna.MathProg.MasterConvexityConstr, 4.0, ClMP.Less, nothing)
        ]
    )

    spform, sp_name_to_var, sp_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            Coluna.MathProg.getid(master_name_to_var["pricing_setup"]),
            Coluna.MathProg.getid(master_name_to_constr["c2"]),
            Coluna.MathProg.getid(master_name_to_constr["c3"]),
            Coluna.MathProg.Integ,
        ),
        [
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x1"]), Coluna.MathProg.getuid(master)),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x2"]), Coluna.MathProg.getuid(master))
        ],
        []
    )

    var_ids = [Coluna.MathProg.getid(sp_name_to_var["x1"]), Coluna.MathProg.getid(sp_name_to_var["x2"])]
    pool = Coluna.MathProg.get_primal_sol_pool(spform)

    for (name, vals) in Iterators.zip(
        ["MC1", "MC2", "MC3"],
        [
            # x1, x2
            Float64[1.0, 2.0],
            Float64[1.0, 1.0],
            Float64[0.0, 1.0]
        ]
    )
        col_id = Coluna.MathProg.VarId(
            Coluna.MathProg.getid(master_name_to_var[name]),
            origin_form_uid = Coluna.MathProg.getuid(spform),
            duty = Coluna.MathProg.DwSpPrimalSol
        )
        Coluna.MathProg.push_in_pool!(
            pool,
            Coluna.MathProg.PrimalSolution(spform, var_ids, vals, 1.0, Coluna.MathProg.FEASIBLE_SOL),
            col_id,
            1.0
        )
    end

    dw_pricing_sps = Dict(
        Coluna.MathProg.getuid(spform) => spform
    )

    presolve_master_repr = _presolve_formulation(
        ["x1", "x2", "y1", "y2"],
        ["c1"],
        [1 1 2 1],
        master,
        master_name_to_var,
        master_name_to_constr,
    )

    presolve_master_restr = _presolve_formulation(
        ["MC1", "MC2", "MC3", "y1", "y2"],
        ["c1", "c2", "c3"],
        [1 1 3 2 1; 1 1 1 0 0; 1 1 1 0 0],
        master,
        master_name_to_var,
        master_name_to_constr,
    )

    local_restr_partial_sol = [0.0, 1.0, 2.0, 1.0, 0.0] # MC2 = 1, MC3 = 2, y1 = 1.

    partial_sol_on_repr, _ = Coluna.Algorithm.partial_sol_on_repr(
        dw_pricing_sps,
        presolve_master_repr,
        presolve_master_restr,
        local_restr_partial_sol
    )

    @test partial_sol_on_repr == [
        1.0, # 1.0 MC2 with x1 = 1.0 & 2.0 MC3 with x1 = 0.0
        3.0, # 1.0 MC2 with x2 = 1.0 & 2.0 MC3 with x2 = 1.0
        1.0, # y1
        0.0  # y2
    ]
end
register!(unit_tests, "presolve_algorithm", test_partial_sol_on_repr)

function test_update_subproblem_multiplicities()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    # original master:
    # min x1 + x2 + 5y1 + 0y2 + MC1 + 2MC2 + 4MC3
    # c1: x1 + x2 + 3MC1 + 2MC2 + 1MC3 + 2y1 + 2y2 >= 4
    # c2: MC1 + MC2 + MC3 >= 0
    # c3: MC1 + MC2 + MC3 <= 4
    # 0 <= x1 <= 1
    # 0 <= x2 <= 2
    # 0 <= MC1 <= 1
    # 1 <= MC2 <= 1
    # 2 <= MC3 <= 4
    # y1 >= 1.5
    # y2 >= 2.5

    master, master_name_to_var, master_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 1.0, nothing, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 2.0, nothing, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing, 2),
            ("MC2", Coluna.MathProg.MasterCol, 2.0, 1.0, 1.0, nothing, 2),
            ("MC3", Coluna.MathProg.MasterCol, 4.0, 2.0, 4.0, nothing, 2),
            ("y1", Coluna.MathProg.MasterPureVar, 5.0, 1.5, Inf, nothing, nothing),
            ("y2", Coluna.MathProg.MasterPureVar, 0.0, 2.5, Inf, nothing, nothing),
            ("pricing_setup", Coluna.MathProg.MasterRepPricingSetupVar, 0.0, 1.0, 1.0, nothing, nothing)
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.MasterConvexityConstr, 0.0, ClMP.Greater, nothing),
            ("c3", Coluna.MathProg.MasterConvexityConstr, 4.0, ClMP.Less, nothing),
        ]
    )

    spform, sp_name_to_var, sp_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            Coluna.MathProg.getid(master_name_to_var["pricing_setup"]),
            Coluna.MathProg.getid(master_name_to_constr["c2"]),
            Coluna.MathProg.getid(master_name_to_constr["c3"]),
            Coluna.MathProg.Integ,
        ),
        [
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x1"]), Coluna.MathProg.getuid(master)),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x2"]), Coluna.MathProg.getuid(master))
        ],
        [
            # name, duty, rhs, sense, id
            ("c4", Coluna.MathProg.DwSpPureConstr, 2.0, ClMP.Greater, nothing)
        ]
    )

    var_ids = [Coluna.MathProg.getid(sp_name_to_var["x1"]), Coluna.MathProg.getid(sp_name_to_var["x2"])]
    pool = Coluna.MathProg.get_primal_sol_pool(spform)

    for (name, vals) in Iterators.zip(
        ["MC1", "MC2", "MC3"],
        [
            # x1, x2
            Float64[1.0, 2.0],
            Float64[1.0, 1.0],
            Float64[0.0, 1.0]
        ]
    )
        col_id = Coluna.MathProg.VarId(
            Coluna.MathProg.getid(master_name_to_var[name]),
            origin_form_uid = Coluna.MathProg.getuid(spform),
            duty = Coluna.MathProg.DwSpPrimalSol
        )
        Coluna.MathProg.push_in_pool!(
            pool,
            Coluna.MathProg.PrimalSolution(spform, var_ids, vals, 1.0, Coluna.MathProg.FEASIBLE_SOL),
            col_id,
            1.0
        )
    end

    dw_pricing_sps = Dict(
        Coluna.MathProg.getuid(spform) => spform
    )

    presolve_master_repr = _presolve_formulation(
        ["x1", "x2"],
        ["c1"],
        [1 1],
        master,
        master_name_to_var,
        master_name_to_constr,
    )

    presolve_master_restr = _presolve_formulation(
        ["MC1", "MC2", "MC3", "y1", "y2"],
        ["c1", "c2", "c3"],
        [3 2 1 2 2; 1 1 1 0 0; 1 1 1 0 0],
        master,
        master_name_to_var,
        master_name_to_constr,
    )

    presolve_sp = _presolve_formulation(
        ["x1", "x2"],
        ["c4"],
        [1 1],
        spform,
        sp_name_to_var,
        sp_name_to_constr;
        lm = 0,
        um = 4
    )

    local_restr_partial_sol = [0.0, 1.0, 2.0, 1.0, 0.0] # MC2 = 1, MC3 = 2, y1 = 1.

    _, nb_fixed_columns_per_sp = Coluna.Algorithm.partial_sol_on_repr(
        dw_pricing_sps,
        presolve_master_repr,
        presolve_master_restr,
        local_restr_partial_sol
    )

    presolve_pricing_sps = Dict(
        Coluna.MathProg.getuid(spform) => presolve_sp
    )

    sp_form_uid = Coluna.MathProg.getuid(spform)
    @test nb_fixed_columns_per_sp[sp_form_uid] == 3 # 3 columns fixed.

    @test presolve_pricing_sps[sp_form_uid].form.lower_multiplicity == 0
    @test presolve_pricing_sps[sp_form_uid].form.upper_multiplicity == 4

    Coluna.Algorithm.update_subproblem_multiplicities!(presolve_pricing_sps, nb_fixed_columns_per_sp)

    @test presolve_pricing_sps[sp_form_uid].form.lower_multiplicity == 0
    @test presolve_pricing_sps[sp_form_uid].form.upper_multiplicity == 4 - 3
end
register!(unit_tests, "presolve_algorithm", test_update_subproblem_multiplicities)

function test_compute_repr_master_var_domains_and_propagate_partial_sol_into_master()
    env = Coluna.Env{Coluna.MathProg.VarId}(Coluna.Params())

    # original master:
    # min x1 + x2 + 5y1 + 0y2 + MC1 + 2MC2 + 4MC3
    # c1: x1 + x2 + 3MC1 + 2MC2 + 1MC3 + 2y1 + 2y2 >= 4
    # c2: MC1 + MC2 + MC3 >= 0
    # c3: MC1 + MC2 + MC3 <= 4
    # 0 <= x1 <= 1
    # 0 <= x2 <= 2
    # 0 <= MC1 <= 1
    # 1 <= MC2 <= 1
    # 2 <= MC3 <= 4
    # y1 >= 1.5
    # y2 >= 2.5

    master, master_name_to_var, master_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwMaster(),
        [
            # name, duty, cost, lb, ub, id
            ("x1", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 4.0, nothing, nothing),
            ("x2", Coluna.MathProg.MasterRepPricingVar, 1.0, 0.0, 8.0, nothing, nothing),
            ("MC1", Coluna.MathProg.MasterCol, 1.0, 0.0, 1.0, nothing, 2),
            ("MC2", Coluna.MathProg.MasterCol, 2.0, 1.0, 1.0, nothing, 2),
            ("MC3", Coluna.MathProg.MasterCol, 4.0, 2.0, 4.0, nothing, 2),
            ("y1", Coluna.MathProg.MasterPureVar, 5.0, 1.5, Inf, nothing, nothing),
            ("y2", Coluna.MathProg.MasterPureVar, 0.0, 2.5, Inf, nothing, nothing),
            ("pricing_setup", Coluna.MathProg.MasterRepPricingSetupVar, 0.0, 1.0, 1.0, nothing, nothing)
        ],
        [
            # name, duty, rhs, sense , id
            ("c1", Coluna.MathProg.MasterMixedConstr, 4.0, ClMP.Greater, nothing),
            ("c2", Coluna.MathProg.MasterConvexityConstr, 0.0, ClMP.Greater, nothing),
            ("c3", Coluna.MathProg.MasterConvexityConstr, 4.0, ClMP.Less, nothing),
        ]
    )

    spform, sp_name_to_var, sp_name_to_constr = _mathprog_formulation!(
        env,
        Coluna.MathProg.DwSp(
            Coluna.MathProg.getid(master_name_to_var["pricing_setup"]),
            Coluna.MathProg.getid(master_name_to_constr["c2"]),
            Coluna.MathProg.getid(master_name_to_constr["c3"]),
            Coluna.MathProg.Integ,
        ),
        [
            ("x1", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 1.0, Coluna.Algorithm.getid(master_name_to_var["x1"]), Coluna.MathProg.getuid(master)),
            ("x2", Coluna.MathProg.DwSpPricingVar, 1.0, 0.0, 2.0, Coluna.Algorithm.getid(master_name_to_var["x2"]), Coluna.MathProg.getuid(master))
        ],
        [
            # name, duty, rhs, sense, id
            ("c4", Coluna.MathProg.DwSpPureConstr, 2.0, ClMP.Greater, nothing)
        ]
    )

    var_ids = [Coluna.MathProg.getid(sp_name_to_var["x1"]), Coluna.MathProg.getid(sp_name_to_var["x2"])]
    pool = Coluna.MathProg.get_primal_sol_pool(spform)

    for (name, vals) in Iterators.zip(
        ["MC1", "MC2", "MC3"],
        [
            # x1, x2
            Float64[1.0, 2.0],
            Float64[1.0, 1.0],
            Float64[0.0, 1.0]
        ]
    )
        col_id = Coluna.MathProg.VarId(
            Coluna.MathProg.getid(master_name_to_var[name]),
            origin_form_uid = Coluna.MathProg.getuid(spform),
            duty = Coluna.MathProg.DwSpPrimalSol
        )
        Coluna.MathProg.push_in_pool!(
            pool,
            Coluna.MathProg.PrimalSolution(spform, var_ids, vals, 1.0, Coluna.MathProg.FEASIBLE_SOL),
            col_id,
            1.0
        )
    end

    dw_pricing_sps = Dict(
        Coluna.MathProg.getuid(spform) => spform
    )

    presolve_master_repr = _presolve_formulation(
        ["x1", "x2"],
        ["c1"],
        [1 1],
        master,
        master_name_to_var,
        master_name_to_constr,
    )

    presolve_master_restr = _presolve_formulation(
        ["MC1", "MC2", "MC3", "y1", "y2"],
        ["c1", "c2", "c3"],
        [3 2 1 2 2; 1 1 1 0 0; 1 1 1 0 0],
        master,
        master_name_to_var,
        master_name_to_constr,
    )

    presolve_sp = _presolve_formulation(
        ["x1", "x2"],
        ["c4"],
        [1 1],
        spform,
        sp_name_to_var,
        sp_name_to_constr;
        lm = 0,
        um = 4
    )

    presolve_dw_sps = Dict(
        Coluna.MathProg.getuid(spform) => presolve_sp
    )

    local_restr_partial_sol = [0.0, 1.0, 2.0, 1.0, 0.0] # MC2 = 1, MC3 = 2, y1 = 1.

    _, nb_fixed_columns_per_sp = Coluna.Algorithm.partial_sol_on_repr(
        dw_pricing_sps,
        presolve_master_repr,
        presolve_master_restr,
        local_restr_partial_sol
    )

    presolve_pricing_sps = Dict(
        Coluna.MathProg.getuid(spform) => presolve_sp
    )

    Coluna.Algorithm.update_subproblem_multiplicities!(presolve_pricing_sps, nb_fixed_columns_per_sp)
    presolve_reform = Coluna.Algorithm.DwPresolveReform(
        presolve_master_repr, 
        presolve_master_restr, 
        presolve_pricing_sps
    )
    var_domains = Coluna.Algorithm.compute_repr_master_var_domains(
        dw_pricing_sps,
        presolve_reform,
        local_restr_partial_sol
    )
    # variable domains are computed only using new multiplicity of the subproblems.
    @test var_domains[1] == (0, 1)
    @test var_domains[2] == (0, 2)

    local_repr_partial_sol = [1.0, 3.0]

    Coluna.Algorithm.propagate_partial_sol_to_global_bounds!(
        presolve_master_repr,
        local_repr_partial_sol,
        var_domains
    )

    # new global bounds from the partial solution propagation are:
    # -1 <= x1 <= 3 
    # -3 <= x2 <= 5
    # which are dominated by the global bounds computed from the sp multiplicity.

    @test presolve_master_repr.form.lbs[1] == 0
    @test presolve_master_repr.form.ubs[1] == 1
    @test presolve_master_repr.form.lbs[2] == 0
    @test presolve_master_repr.form.ubs[2] == 2
end
register!(unit_tests, "presolve_algorithm", test_compute_repr_master_var_domains_and_propagate_partial_sol_into_master)

function test_presolve_full()
    formstring = """
    master
        min
        1.0 x_1 + 1.0 x_2 + 1.0 x_3 + 1.0 x_4 + 1.0 x_5 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4 
        s.t.
        2.0 x_1 + 3.0 x_2 + 1.0 x_3 + 0.0 x_4 + 1.0 x_5 == 5.0
        0.0 x_1 + 0.0 x_2 + 0.0 x_3 + 1.0 x_4 + 0.0 x_5 >= 2.0
        1.0 PricingSetupVar_sp_4 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 <= 2.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 <= 2.0 {MasterConvexityConstr}

    dw_sp
        min
        x_3 + x_4 + 0.0 PricingSetupVar_sp_5
        s.t.
        1.0 x_3 + 1.0 x_4 >= 4.0

    dw_sp
        min
        x_1 + x_2 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_1 + 1.0 x_2 >= 1.0
        solutions
        1.0 x_1 {MC_1}

    continuous
        pure
            x_5

    integer
        pricing_setup
            PricingSetupVar_sp_4, PricingSetupVar_sp_5
        representatives
            x_1, x_2, x_3, x_4

    bounds
        0.0 <= x_1 <= 1.0
        0.0 <= x_2 <= 1.0
        0.0 <= x_3 <= 3.0
        0.0 <= x_4 <= 3.0
        0.0 <= x_5 <= 1.0
        1.0 <= PricingSetupVar_sp_4 <= 1.0
        1.0 <= PricingSetupVar_sp_5 <= 1.0
    """
    env, master, sps, _, reform = reformfromstring(formstring)

    #print(IOContext(stdout, :user_only => true), reform)

    master_vars = Dict{String, Coluna.MathProg.VarId}(
        Coluna.MathProg.getname(master, var) => varid 
        for (varid, var) in Coluna.MathProg.getvars(master)
    )

    master_constrs = Dict{String, Coluna.MathProg.ConstrId}(
        Coluna.MathProg.getname(master, constr) => constrid 
        for (constrid, constr) in Coluna.MathProg.getconstrs(master)
    )

    presolve_algorithm = Coluna.Algorithm.PresolveAlgorithm(; verbose=true)
    input = Coluna.Algorithm.PresolveInput(
        Dict(master_vars["MC_1"] => 1.0, master_vars["x_5"] => 1.0)
    )
    
    output = Coluna.Algorithm.run!(presolve_algorithm, env, reform, input)

    #print(IOContext(stdout, :user_only => true), reform)
    #print(Coluna.MathProg.getmaster(reform))

    @test output.feasible == true
    @test Coluna.MathProg.getcurlb(master, master_vars["x_1"]) == 0.0
    @test Coluna.MathProg.getcurub(master, master_vars["x_1"]) == 0.0
    @test Coluna.MathProg.getcurlb(master, master_vars["x_2"]) == 0.0
    @test Coluna.MathProg.getcurub(master, master_vars["x_2"]) == 0.0
    @test Coluna.MathProg.getcurlb(master, master_vars["x_3"]) == 2.0
    @test Coluna.MathProg.getcurub(master, master_vars["x_3"]) == 2.0
    @test Coluna.MathProg.getcurlb(master, master_vars["x_4"]) == 2.0
    @test Coluna.MathProg.getcurub(master, master_vars["x_4"]) == 3.0
    @test Coluna.MathProg.getcurlb(master, master_vars["x_5"]) == 0.0
    @test Coluna.MathProg.getcurub(master, master_vars["x_5"]) == 0.0
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c1"]) == 2.0
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c2"]) == 2.0
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c3"]) == 0.0 # l_mult of sp4
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c4"]) == 0.0 # u_mult of sp4
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c5"]) == 1.0 # l_mult of sp5
    @test Coluna.MathProg.getcurrhs(master, master_constrs["c6"]) == 1.0 # u_mult of sp5
    
    master_partal_sol = Coluna.MathProg.getpartialsol(master)
    @test master_partal_sol[master_vars["x_5"]] == 1.0
    @test master_partal_sol[master_vars["MC_1"]] == 1.0

    sp5_index = findfirst(sp->Coluna.MathProg.getuid(sp) == 5, sps)
    @test sp5_index !== nothing
    sp5 = sps[sp5_index]
    sp5_vars = Dict{String, Coluna.MathProg.VarId}(
        Coluna.MathProg.getname(sp5, var) => varid 
        for (varid, var) in Coluna.MathProg.getvars(sp5)
    )

    @test Coluna.MathProg.getcurlb(sp5, sp5_vars["x_3"]) == 2.0
    @test Coluna.MathProg.getcurub(sp5, sp5_vars["x_3"]) == 2.0
    @test Coluna.MathProg.getcurlb(sp5, sp5_vars["x_4"]) == 2.0
    @test Coluna.MathProg.getcurub(sp5, sp5_vars["x_4"]) == 3.0
    
    sp4_index = findfirst(sp->Coluna.MathProg.getuid(sp) == 4, sps)
    @test sp4_index !== nothing
    sp4 = sps[sp4_index]
    sp4_vars = Dict{String, Coluna.MathProg.VarId}(
        Coluna.MathProg.getname(sp4, var) => varid 
        for (varid, var) in Coluna.MathProg.getvars(sp4)
    )

    @test Coluna.MathProg.getcurub(sp4, sp4_vars["x_1"]) == 0.0
    @test Coluna.MathProg.getcurlb(sp4, sp4_vars["x_2"]) == 1.0


    return nothing
end

register!(unit_tests, "presolve_reformulation", test_presolve_full)
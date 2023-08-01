function strong_branching_simple_form()
    # All the tests are based on the Generalized Assignment problem.
    # x_mj = 1 if job j is assigned to machine m

    form = """
    master
        min
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 51.0 MC_30 + 38.0 MC_31 + 31.0 MC_32 + 35.0 MC_33 + 48.0 MC_34 + 13.0 MC_35 + 53.0 MC_36 + 28.0 MC_37 + 2.0 MC_38 + 3.0 MC_39 + 2.0 MC_40 + 2.0 MC_41 + 4.0 MC_42 + 3.0 MC_43 + 3.0 MC_44 + 2.0 MC_45 + 4.0 MC_46 + 3.0 MC_47 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_39 + 1.0 MC_44 + 1.0 MC_45 + 1.0 MC_47  >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_40 + 1.0 MC_41 + 1.0 MC_42 + 1.0 MC_43 + 1.0 MC_44 + 1.0 MC_45 + 1.0 MC_46 >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_37 + 1.0 MC_38 + 1.0 MC_42 + 1.0 MC_44 + 1.0 MC_46 >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_37 + 1.0 MC_46 + 1.0 MC_47 >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_31 + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_46 + 1.0 MC_47 >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_36 + 1.0 MC_38 + 1.0 MC_39 + 1.0 MC_43 >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_34 + 1.0 MC_36 + 1.0 MC_37 + 1.0 MC_37 + 1.0 MC_40 + 1.0 MC_41 + 1.0 MC_42 + 1.0 MC_43 >= 1.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_36 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45 + 1.0 MC_47 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_36 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45 + 1.0 MC_47 <= 1.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_37 + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44 + 1.0 MC_46 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_37 + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44 + 1.0 MC_46 <= 1.0 {MasterConvexityConstr}

    dw_sp
        min
        x_11 + x_12 + x_13 + x_14 + x_15 + x_16 + x_17 + 0.0 PricingSetupVar_sp_5  
        s.t.
        2.0 x_11 + 3.0 x_12 + 3.0 x_13 + 1.0 x_14 + 2.0 x_15 + 1.0 x_16 + 1.0 x_17  <= 5.0

    dw_sp
        min
        x_21 + x_22 + x_23 + x_24 + x_25 + x_26 + x_27 + 0.0 PricingSetupVar_sp_4
        s.t.
        5.0 x_21 + 1.0 x_22 + 1.0 x_23 + 3.0 x_24 + 1.0 x_25 + 5.0 x_26 + 4.0 x_27  <= 8.0

    continuous
        columns
            MC_30, MC_31, MC_32, MC_33, MC_34, MC_35, MC_36, MC_37, MC_38, MC_39, MC_40, MC_41, MC_42, MC_43, MC_44, MC_45, MC_46, MC_47

        artificial
            local_art_of_cov_5, local_art_of_cov_4, local_art_of_cov_6, local_art_of_cov_7, local_art_of_cov_2, local_art_of_cov_3, local_art_of_cov_1, local_art_of_sp_lb_5, local_art_of_sp_ub_5, local_art_of_sp_lb_4, local_art_of_sp_ub_4, global_pos_art_var, global_neg_art_var

    integer
        pricing_setup
            PricingSetupVar_sp_4, PricingSetupVar_sp_5

    binary
        representatives
            x_11, x_21, x_12, x_22, x_13, x_23, x_14, x_24, x_15, x_25, x_16, x_26, x_17, x_27

    bounds
        0.0 <= x_11 <= 1.0
        0.0 <= x_21 <= 1.0
        0.0 <= x_12 <= 1.0
        0.0 <= x_22 <= 1.0
        0.0 <= x_13 <= 1.0
        0.0 <= x_23 <= 1.0
        0.0 <= x_14 <= 1.0
        0.0 <= x_24 <= 1.0
        0.0 <= x_15 <= 1.0
        0.0 <= x_25 <= 1.0
        0.0 <= x_16 <= 1.0
        0.0 <= x_26 <= 1.0
        0.0 <= x_17 <= 1.0
        0.0 <= x_27 <= 1.0
        1.0 <= PricingSetupVar_sp_4 <= 1.0
        1.0 <= PricingSetupVar_sp_5 <= 1.0
        local_art_of_cov_5 >= 0.0
        local_art_of_cov_4 >= 0.0
        local_art_of_cov_6 >= 0.0
        local_art_of_cov_7 >= 0.0
        local_art_of_cov_2 >= 0.0
        local_art_of_cov_3 >= 0.0
        local_art_of_cov_1 >= 0.0
        local_art_of_sp_lb_5 >= 0.0
        local_art_of_sp_ub_5 >= 0.0
        local_art_of_sp_lb_4 >= 0.0
        local_art_of_sp_ub_4 >= 0.0
        global_pos_art_var >= 0.0
        global_neg_art_var >= 0.0
        MC_30 >= 0.0
        MC_31 >= 0.0
        MC_32 >= 0.0
        MC_33 >= 0.0
        MC_34 >= 0.0
        MC_35 >= 0.0
        MC_36 >= 0.0
        MC_37 >= 0.0
        MC_38 >= 0.0
        MC_39 >= 0.0
        MC_40 >= 0.0
        MC_41 >= 0.0
        MC_42 >= 0.0
        MC_43 >= 0.0
        MC_44 >= 0.0
        MC_45 >= 0.0
        MC_46 >= 0.0
        MC_47 >= 0.0
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_strong_branching()
    env, master, sps, reform = strong_branching_simple_form()
    env.params.local_art_var_cost = 1.0
    Coluna.set_optim_start_time!(env)

    # Define optimizers for the formulations.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    # Create the master lp solution.
    vars = Dict{String, Coluna.MathProg.VarId}(Coluna.MathProg.getname(master, var) => varid for (varid, var) in Coluna.MathProg.getvars(master))
    _id(id, orig_form_id) = Coluna.MathProg.VarId(id; origin_form_uid = orig_form_id)

    ####
    # colgen_output = Coluna.Algorithm.ColGenOutput(Primal solution
    # | MC_36 = 0.5
    # | MC_38 = 0.16666667
    # | MC_39 = 0.16666667
    # | MC_42 = 0.33333333
    # | MC_43 = 0.16666667
    # | MC_44 = 0.16666667
    # | MC_46 = 0.33333333
    # | MC_47 = 0.16666667
    # └ value = 31.50 

    extended_sol = Coluna.PrimalSolution(
        master,
        [
            _id(vars["MC_36"], 4),
            _id(vars["MC_38"], 4),
            _id(vars["MC_39"], 5),
            _id(vars["MC_42"], 4),
            _id(vars["MC_43"], 5),
            _id(vars["MC_44"], 4),
            _id(vars["MC_46"], 4),
            _id(vars["MC_47"], 5)
        ],
        [0.5, 0.16666667, 0.16666667, 0.33333333, 0.16666667, 0.16666667, 0.33333333, 0.16666667],
        31.5,
        Coluna.ColunaBase.FEASIBLE_SOL
    )

    # Pool of first subproblem
    col_items = Dict(
        "MC_30" => [4, 5, 6, 7],
        "MC_31" => [1, 2, 3, 5],
        "MC_32" => [2, 4, 6],
        "MC_33" => [2, 3, 4],
        "MC_34" => [1, 4, 7],
        "MC_35" => [1, 4],
        "MC_36" => [1, 4, 6, 7],
        "MC_37" => [3, 4, 7],
        "MC_38" => [3, 6],
        "MC_39" => [1, 5, 7],
        "MC_40" => [2, 5],
        "MC_41" => [2, 5],
        "MC_42" => [2, 3, 5, 6],
        "MC_43" => [2, 3, 6],
        "MC_44" => [1, 3, 5, 6],
        "MC_45" => [1, 5],
        "MC_46" => [2, 3, 5, 7],
        "MC_47" => [1, 3, 7]
    )

    pool = Coluna.MathProg.get_primal_sol_pool(sps[1])

    col_names =  ["MC_31", "MC_33", "MC_35", "MC_37", "MC_39", "MC_41", "MC_43", "MC_45", "MC_47"]
    vars_sp1 = Dict{String, Coluna.MathProg.VarId}(Coluna.MathProg.getname(sps[1], var) => varid for (varid, var) in Coluna.MathProg.getvars(sps[1]))
    for col_name in col_names
        col_id = Coluna.MathProg.VarId(vars[col_name]; duty = Coluna.MathProg.DwSpPrimalSol)
        var_ids = [vars_sp1["x_2$i"] for i in col_items[col_name]]
        var_vals = ones(Float64, length(var_ids))
        primal_sol = MathProg.PrimalSolution(master, var_ids, var_vals, 0.0, MathProg.FEASIBLE_SOL)
        MathProg.push_in_pool!(pool, primal_sol, col_id, 1.0)
    end

    # Pool of second subproblem
    pool = Coluna.MathProg.get_primal_sol_pool(sps[2])

    col_names =["MC_30", "MC_32", "MC_34", "MC_36", "MC_38", "MC_40", "MC_42", "MC_44", "MC_46"]
    vars_sp2 = Dict{String, Coluna.MathProg.VarId}(Coluna.MathProg.getname(sps[2], var) => varid for (varid, var) in Coluna.MathProg.getvars(sps[2]))
    for col_name in col_names
        col_id = Coluna.MathProg.VarId(vars[col_name]; duty = Coluna.MathProg.DwSpPrimalSol)
        vars_sp2 = Dict{String, Coluna.MathProg.VarId}(Coluna.MathProg.getname(sps[1], var) => varid for (varid, var) in Coluna.MathProg.getvars(sps[2]))
        var_ids = [vars_sp2["x_1$i"] for i in col_items[col_name]]
        var_vals = ones(Float64, length(var_ids))
        primal_sol = MathProg.PrimalSolution(master, var_ids, var_vals, 0.0, MathProg.FEASIBLE_SOL)
        MathProg.push_in_pool!(pool, primal_sol, col_id, 1.0)
    end

    ### Algorithm
    conquer1 = Coluna.Algorithm.RestrMasterLPConquer()
    conquer2 = Coluna.Algorithm.ColCutGenConquer()

    phases = [
        Coluna.Algorithm.PhasePrinter(
            Coluna.Algorithm.StrongBranchingPhaseContext(
                Coluna.Algorithm.BranchingPhase(
                    3, conquer1, Coluna.Algorithm.ProductScore()
                ),
                Coluna.Algorithm.UnitsUsage()
            ), 1
        ),
        Coluna.Algorithm.PhasePrinter(
            Coluna.Algorithm.StrongBranchingPhaseContext(
                Coluna.Algorithm.BranchingPhase(
                    1, conquer2, Coluna.Algorithm.ProductScore()
                ),
                Coluna.Algorithm.UnitsUsage()
            ), 2
        )
    ]

    rules = [
        Coluna.Branching.PrioritisedBranchingRule(Coluna.SingleVarBranchingRule(), 1.0, 1.0)
    ]

    ctx = Coluna.Algorithm.BranchingPrinter(
        Coluna.Algorithm.StrongBranchingContext(
            phases,
            rules,
            Coluna.Algorithm.MostFractionalCriterion(),
            1e-5
        )
    )

    conquer_output = Coluna.Algorithm.OptimizationState(
        master;
        lp_dual_bound = 31.5
    )
    Coluna.Algorithm.update_lp_primal_sol!(conquer_output, extended_sol)

    # TODO: interface to register Records.
    records = Coluna.Algorithm.Records()
    node = Coluna.Algorithm.Node(
        0, "", nothing, MathProg.DualBound(reform), records, false 
    )

    global_primal_handler = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    input = Coluna.Algorithm.DivideInputFromBaB(
        0, conquer_output, records, global_primal_handler
    )
    original_sol = Coluna.Algorithm.get_original_sol(reform, conquer_output)

    @show extended_sol
    @show original_sol

    Branching.run_branching!(ctx, env, reform, input, extended_sol, original_sol)
end
register!(unit_tests, "branching", test_strong_branching)
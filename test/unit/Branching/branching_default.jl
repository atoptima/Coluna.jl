function strong_branching_simple_form()
    # All the tests are based on the Generalized Assignment problem.
    # x_mj = 1 if job j is assigned to machine m

    form = """
    master
        min
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 51.0 MC_30 + 38.0 MC_31 + 31.0 MC_32 + 35.0 MC_33 + 48.0 MC_34 + 13.0 MC_35 + 53.0 MC_36 + 28.0 MC_37 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36  >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_32 + 1.0 MC_33 >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_37  >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_37  >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_31  >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_36  >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_34 + 1.0 MC_36 + 1.0 MC_37 >= 1.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_36  >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_36  <= 1.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_37  >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_37  <= 1.0 {MasterConvexityConstr}

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
            MC_30, MC_31, MC_32, MC_33, MC_34, MC_35, MC_36, MC_37

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
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_strong_branching()
    env, master, sps, reform = strong_branching_simple_form()
    env.params.local_art_var_cost = 1.0
    Coluna.set_optim_start_time!(env)

    @show master
    @show sps

    # Define optimizers for the formulations.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    # Create the master lp solution.
    vars = Dict{String, Coluna.MathProg.VarId}(Coluna.MathProg.getname(master, var) => varid for (varid, var) in Coluna.MathProg.getvars(master))
    _id(id, orig_form_id) = Coluna.MathProg.VarId(id; origin_form_uid = orig_form_id)
    extended_sol = Coluna.PrimalSolution(
        master,
        [_id(vars["MC_30"], 3), _id(vars["MC_32"], 3), _id(vars["MC_34"], 3), _id(vars["MC_31"], 2), _id(vars["MC_35"], 2)],
        [1/4, 1/4, 1/2, 1/3, 2/3],
        45.0,
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
        "MC_37" => [3, 4, 7]
    )

    @show sps[1]
    pool = Coluna.MathProg.get_primal_sol_pool(sps[1])
    pool_hashtable = Coluna.MathProg._get_primal_sol_pool_hash_table(sps[1])
    costs_pool = sps[1].duty_data.costs_primalsols_pool
    custom_pool = sps[1].duty_data.custom_primalsols_pool

    col_names =  ["MC_31", "MC_33", "MC_35", "MC_37"]
    for col_name in col_names
        col_id = Coluna.MathProg.VarId( vars[col_name]; duty = Coluna.MathProg.DwSpPrimalSol)
        var_ids = [vars["x_2$i"] for i in col_items[col_name]]
        var_vals = ones(Float64, length(var_ids))
        DynamicSparseArrays.addrow!(pool, col_id, var_ids, var_vals)
    end

    # Pool of second subproblem
    @show sps[2]
    pool = Coluna.MathProg.get_primal_sol_pool(sps[2])
    pool_hashtable = Coluna.MathProg._get_primal_sol_pool_hash_table(sps[2])
    costs_pool = sps[2].duty_data.costs_primalsols_pool
    custom_pool = sps[2].duty_data.custom_primalsols_pool

    col_names =["MC_30", "MC_32", "MC_34", "MC_36"]
    for col_name in col_names
        col_id = Coluna.MathProg.VarId( vars[col_name]; duty = Coluna.MathProg.DwSpPrimalSol)
        var_ids = [vars["x_1$i"] for i in col_items[col_name]]
        var_vals = ones(Float64, length(var_ids))
        DynamicSparseArrays.addrow!(pool, col_id, var_ids, var_vals)
    end

    ### Algorithm

    conquer1 = Coluna.Algorithm.ColCutGenConquer()
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

    optstate = Coluna.Algorithm.OptimizationState(master)
    Coluna.Algorithm.update_lp_primal_sol!(optstate, extended_sol)
    records = Coluna.Algorithm.Records()
    node = Coluna.Algorithm.Node(
        0, nothing, optstate, "", records, false 
    )

    input = Coluna.Algorithm.DivideInputFromBaB(
        node, optstate
    )
    original_sol = Coluna.Algorithm.get_original_sol(reform, optstate)

    @show extended_sol
    @show original_sol

    Branching.run_branching!(ctx, env, reform, input, extended_sol, original_sol)
end
register!(unit_tests, "branching", test_strong_branching; f = true)
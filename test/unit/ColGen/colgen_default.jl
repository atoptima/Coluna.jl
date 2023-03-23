# Minimization and test all constraint senses
form1() = """
master
    min
    3x1 + 2x2 + 5x3 + 4y1 + 3y2 + 5y3
    s.t.
    x1 + x2 + x3 + y1 + y2 + y3  >= 10
    x1 + 2x2     + y1 + 2y2      <= 100
    x1 +     3x3 + y1 +    + 3y3 == 100

dw_sp
    min
    x1 + x2 + x3 + y1 + y2 + y3
    s.t.
    x1 + x2 + x3 + y1 + y2 + y3 >= 10
    
    integer
        representatives
            x1, x2, x3, y1, y2, y3
    
    bounds
        x1 >= 0
        x2 >= 0
        x3 >= 0
        y1 >= 0
        y2 >= 0
        y3 >= 0
"""

function get_name_to_varids(form)
    d = Dict{String, ClMP.VarId}()
    for (varid, var) in ClMP.getvars(form)
        d[ClMP.getname(form, var)] = varid
    end
    return d
end

function get_name_to_constrids(form)
    d = Dict{String, ClMP.ConstrId}()
    for (constrid, constr) in ClMP.getconstrs(form)
        d[ClMP.getname(form, constr)] = constrid
    end
    return d
end

# Simple case with only subproblem representatives variables.
function test_reduced_costs_calculation_helper()
    _, master, _, _, _ = reformfromstring(form1())
    vids = get_name_to_varids(master)
    cids = get_name_to_constrids(master)
    
    helper = ClA.ReducedCostsCalculationHelper(master)
    @test helper.c[vids["x1"]] == 3
    @test helper.c[vids["x2"]] == 2
    @test helper.c[vids["x3"]] == 5
    @test helper.c[vids["y1"]] == 4
    @test helper.c[vids["y2"]] == 3
    @test helper.c[vids["y3"]] == 5

    @test helper.A[cids["c1"], vids["x1"]] == 1
    @test helper.A[cids["c1"], vids["x2"]] == 1
    @test helper.A[cids["c1"], vids["x3"]] == 1
    @test helper.A[cids["c1"], vids["y1"]] == 1
    @test helper.A[cids["c1"], vids["y2"]] == 1
    @test helper.A[cids["c1"], vids["y3"]] == 1

    @test helper.A[cids["c2"], vids["x1"]] == 1
    @test helper.A[cids["c2"], vids["x2"]] == 2
    @test helper.A[cids["c2"], vids["y1"]] == 1
    @test helper.A[cids["c2"], vids["y2"]] == 2

    @test helper.A[cids["c3"], vids["x1"]] == 1
    @test helper.A[cids["c3"], vids["x3"]] == 3
    @test helper.A[cids["c3"], vids["y1"]] == 1
    @test helper.A[cids["c3"], vids["y3"]] == 3
end
register!(unit_tests, "colgen_default", test_reduced_costs_calculation_helper)


# All the tests are based on the Generalized Assignment problem.
# x_mj = 1 if job j is assigned to machine m

function min_toy_gap()
    # We introduce variables z1 & z2 to force dual value of constraint c7 to equal to 28.
    form = """
master
    min
    100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 51.0 MC_30 + 38.0 MC_31 + 31.0 MC_32 + 35.0 MC_33 + 48.0 MC_34 + 13.0 MC_35 + 53.0 MC_36 + 28.0 MC_37 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4 + 28 z1 - 28 z2
    s.t.
    1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36  >= 1.0
    1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_32 + 1.0 MC_33 >= 1.0
    1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_37  >= 1.0
    1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_37  >= 1.0
    1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_31  >= 1.0
    1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_36  >= 1.0
    1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_34 + 1.0 MC_36 + 1.0 MC_37 + z1 - z2 >= 1.0
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

    pure
        z1, z2

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
    z1 >= 0.0
    z2 >= 0.0
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function max_toy_gap()
    form = """
master
    max
    - 10000.0 local_art_of_cov_5 - 10000.0 local_art_of_cov_4 - 10000.0 local_art_of_cov_6 - 10000.0 local_art_of_cov_7 - 10000.0 local_art_of_cov_2 - 10000.0 local_art_of_cov_3 - 10000.0 local_art_of_cov_1 - 10000.0 local_art_of_sp_lb_5 - 10000.0 local_art_of_sp_ub_5 - 10000.0 local_art_of_sp_lb_4 - 10000.0 local_art_of_sp_ub_4 - 100000.0 global_pos_art_var - 100000.0 global_neg_art_var + + 53.0 MC_30 + 49.0 MC_31 + 35.0 MC_32 + 45.0 MC_33 + 27.0 MC_34 + 42.0 MC_35 + 45.0 MC_36 + 12.0 MC_37 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
    s.t.
    1.0 x_11 + 1.0 x_21 - 1.0 local_art_of_cov_1 - 1.0 global_neg_art_var + 1.0 MC_30 + 1.0 MC_34 <= 1.0
    1.0 x_12 + 1.0 x_22 - 1.0 local_art_of_cov_2 - 1.0 global_neg_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_37  <= 1.0
    1.0 x_13 + 1.0 x_23 - 1.0 local_art_of_cov_3 - 1.0 global_neg_art_var + 1.0 MC_31 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_35  <= 1.0
    1.0 x_14 + 1.0 x_24 - 1.0 local_art_of_cov_4 - 1.0 global_neg_art_var + 1.0 MC_30 + 1.0 MC_31 + 1.0 MC_36  <= 1.0 
    1.0 x_15 + 1.0 x_25 - 1.0 local_art_of_cov_5 - 1.0 global_neg_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35  <= 1.0 
    1.0 x_16 + 1.0 x_26 - 1.0 local_art_of_cov_6 - 1.0 global_neg_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_33  <= 1.0
    1.0 x_17 + 1.0 x_27 - 1.0 local_art_of_cov_7 - 1.0 global_neg_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36  <= 1.0
    1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_36  >= 0.0 {MasterConvexityConstr}
    1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_34 + 1.0 MC_36  <= 1.0 {MasterConvexityConstr}
    1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_37  >= 0.0 {MasterConvexityConstr}
    1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_37  <= 1.0 {MasterConvexityConstr}

dw_sp
    max
    x_11 + x_12 + x_13 + x_14 + x_15 + x_16 + x_17 + 0.0 PricingSetupVar_sp_5  
    s.t.
    2.0 x_11 + 3.0 x_12 + 3.0 x_13 + 1.0 x_14 + 2.0 x_15 + 1.0 x_16 + 1.0 x_17  <= 5.0

dw_sp
    max
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

function toy_gap_with_penalties()
    form = """
master
    min
    3.15 y_1 + 5.949999999999999 y_2 + 7.699999999999999 y_3 + 11.549999999999999 y_4 + 7.0 y_5 + 4.55 y_6 + 8.399999999999999 y_7 + 10000.0 local_art_of_cov_5 + 10000.0 local_art_of_cov_4 + 10000.0 local_art_of_cov_6 + 10000.0 local_art_of_cov_7 + 10000.0 local_art_of_cov_2 + 10000.0 local_art_of_limit_pen + 10000.0 local_art_of_cov_3 + 10000.0 local_art_of_cov_1 + 10000.0 local_art_of_sp_lb_5 + 10000.0 local_art_of_sp_ub_5 + 10000.0 local_art_of_sp_lb_4 + 10000.0 local_art_of_sp_ub_4 + 100000.0 global_pos_art_var + 100000.0 global_neg_art_var + 51.0 MC_38 + 38.0 MC_39 + 10.0 MC_40 + 28.0 MC_41 + 19.0 MC_42 + 26.0 MC_43 + 31.0 MC_44 + 42.0 MC_45 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
    s.t.
    1.0 x_11 + 1.0 x_21 + 1.0 y_1 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43  >= 1.0
    1.0 x_12 + 1.0 x_22 + 1.0 y_2 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_40 + 1.0 MC_44 + 1.0 MC_45  >= 1.0
    1.0 x_13 + 1.0 x_23 + 1.0 y_3 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  >= 1.0
    1.0 x_14 + 1.0 x_24 + 1.0 y_4 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_44  >= 1.0
    1.0 x_15 + 1.0 x_25 + 1.0 y_5 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43 + 1.0 MC_45  >= 1.0
    1.0 x_16 + 1.0 x_26 + 1.0 y_6 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 1.0
    1.0 x_17 + 1.0 x_27 + 1.0 y_7 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_45  >= 1.0
    1.0 y_1 + 1.0 y_2 + 1.0 y_3 + 1.0 y_4 + 1.0 y_5 + 1.0 y_6 + 1.0 y_7 - 1.0 local_art_of_limit_pen - 1.0 global_neg_art_var  <= 1.0
    1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 0.0 {MasterConvexityConstr}
    1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  <= 1.0 {MasterConvexityConstr}
    1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  >= 0.0 {MasterConvexityConstr}
    1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  <= 1.0 {MasterConvexityConstr}

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
        MC_38, MC_39, MC_40, MC_41, MC_42, MC_43, MC_44, MC_45

    artificial
        local_art_of_cov_5, local_art_of_cov_4, local_art_of_cov_6, local_art_of_cov_7, local_art_of_cov_2, local_art_of_cov_3, local_art_of_cov_1, local_art_of_sp_lb_5, local_art_of_sp_ub_5, local_art_of_sp_lb_4, local_art_of_sp_ub_4, global_pos_art_var, global_neg_art_var, local_art_of_limit_pen
    
    pure
        y_1, y_2, y_3, y_4, y_5, y_6, y_7

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
    local_art_of_limit_pen >= 0
    MC_38 >= 0
    MC_39 >= 0
    MC_40 >= 0
    MC_41 >= 0
    MC_42 >= 0
    MC_43 >= 0
    MC_44 >= 0
    MC_45 >= 0
    0.0 <= y_1 <= 1.0 
    0.0 <= y_2 <= 1.0 
    0.0 <= y_3 <= 1.0 
    0.0 <= y_4 <= 1.0 
    0.0 <= y_5 <= 1.0 
    0.0 <= y_6 <= 1.0 
    0.0 <= y_7 <= 1.0 
"""
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function toy_gap_with_obj_const()
    form = """
master
    min
    100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 51.0 MC_30 + 38.0 MC_31 + 31.0 MC_32 + 35.0 MC_33 + 48.0 MC_34 + 13.0 MC_35 + 53.0 MC_36 + 28.0 MC_37 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4 + 7.0
    s.t.
    1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36  >= 1.0
    1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_32 + 1.0 MC_33  >= 1.0
    1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_37  >= 1.0
    1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_34 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_37  >= 1.0
    1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_31  >= 1.0
    1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_32 + 1.0 MC_36  >= 1.0
    1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_30 + 1.0 MC_34 + 1.0 MC_36 + 1.0 MC_37  >= 1.0
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

### Implementation of ColGen API to test and call the default implementation
struct TestColGenIterationContext <: ColGen.AbstractColGenContext
    context::ClA.ColGenContext
    master_lp_primal_sol::Dict{String, Float64}
    master_lp_dual_sol::Dict{String, Float64}
    master_lp_obj_val::Float64
    pricing_var_reduced_costs::Dict{String, Float64}
end

ColGen.get_reform(ctx::TestColGenIterationContext) = ColGen.get_reform(ctx.context)
ColGen.get_master(ctx::TestColGenIterationContext) = ColGen.get_master(ctx.context)
ColGen.get_pricing_subprobs(ctx::TestColGenIterationContext) = ColGen.get_pricing_subprobs(ctx.context)

function ColGen.optimize_master_lp_problem!(master, ctx::TestColGenIterationContext, env)
    output = ColGen.optimize_master_lp_problem!(master, ctx.context, env)
    primal_sol = ColGen.get_primal_sol(output)
    @show primal_sol
    for (var_id, var) in ClMP.getvars(master)
        name = ClMP.getname(master, var)
        if !haskey(ctx.master_lp_primal_sol, name)
            @test primal_sol[var_id] ≈ 0.0
        else
            @test primal_sol[var_id] ≈ ctx.master_lp_primal_sol[name]
        end
    end

    dual_sol = ColGen.get_dual_sol(output)
    for (constr_id, constr) in ClMP.getconstrs(master)
        name = ClMP.getname(master, constr)
        if !haskey(ctx.master_lp_dual_sol, name)
            @test dual_sol[constr_id] ≈ 0.0
        else
            @test dual_sol[constr_id] ≈ ctx.master_lp_dual_sol[name]
        end
    end
    return output
end

ColGen.is_unbounded(ctx::TestColGenIterationContext) = ColGen.is_unbounded(ctx.context)
ColGen.is_infeasible(ctx::TestColGenIterationContext) = ColGen.is_infeasible(ctx.context)
ColGen.update_master_constrs_dual_vals!(ctx::TestColGenIterationContext, phase, reform, master_lp_dual_sol) = ColGen.update_master_constrs_dual_vals!(ctx.context, phase, reform, master_lp_dual_sol)
ColGen.get_orig_costs(ctx::TestColGenIterationContext) = ColGen.get_orig_costs(ctx.context)
ColGen.get_coef_matrix(ctx::TestColGenIterationContext) = ColGen.get_coef_matrix(ctx.context)

function ColGen.update_sp_vars_red_costs!(ctx::TestColGenIterationContext, sp::Formulation{DwSp}, red_costs)
    for i in 1:5
        println("\e[34m ***************** \e[00m")
    end
    ColGen.update_sp_vars_red_costs!(ctx.context, sp, red_costs)
    for (_, var) in ClMP.getvars(sp)
        name = ClMP.getname(sp, var)
        println(" ---- name = $(name) ---- expected : $(ctx.pricing_var_reduced_costs[name]) ---- actual : $(ClMP.getcurcost(sp, var)) --- cur_cost = $(ClMP.getcurcost(sp, var)))")
        @test ctx.pricing_var_reduced_costs[name] ≈ ClMP.getcurcost(sp, var)
    end
    return
end

ColGen.compute_sp_init_db(ctx::TestColGenIterationContext, sp::Formulation{DwSp}) = ColGen.compute_sp_init_db(ctx.context, sp)
ColGen.set_of_columns(ctx::TestColGenIterationContext) = ColGen.set_of_columns(ctx.context)

# Columns insertion
function ColGen.insert_columns!(reform, ctx::TestColGenIterationContext, phase, columns)
    return ColGen.insert_columns!(reform, ctx.context, phase, columns)
end

function ColGen.optimize_pricing_problem!(ctx::TestColGenIterationContext, sp::Formulation{DwSp}, env, master_dual_sol)
    output = ColGen.optimize_pricing_problem!(ctx.context, sp, env, master_dual_sol)
    # test here
    return output
end

function test_colgen_iteration_min_gap()
    env, master, sps, reform = min_toy_gap()

    # vids = get_name_to_varids(master)
    # cids = get_name_to_constrids(master)
    
    master_lp_primal_sol = Dict(
        "MC_30" => 1/3,
        "MC_31" => 2/3,
        "MC_32" => 1/3,
        "MC_36" => 1/3,
        "MC_37" => 1/3,
    )
    master_lp_dual_sol = Dict(
        "c1" => 11.33333333,
        "c2" => 17.33333333,
        "c5" => 9.33333333,
        "c6" => 13.66666667,
        "c7" => 28.0,
    )
    master_obj_val = 79.67

    pricing_var_reduced_costs = Dict(
        "x_11" => - 3.3333333300000003,
        "x_12" => - 12.333333329999999,
        "x_13" => 11.0,
        "x_14" => 21.0,
        "x_15" => - 3.3333333300000003,
        "x_16" => - 8.66666667,
        "x_17" => - 9.0,
        "PricingSetupVar_sp_5" => 0.0,
        "x_21" => - 10.33333333,
        "x_22" => - 5.3333333299999985,
        "x_23" => 11.0,
        "x_24" => 12.0,
        "x_25" => 4.66666667,
        "x_26" => - 5.66666667,
        "x_27" => - 23.0,
        "PricingSetupVar_sp_4" => 0.0,
    )

    # We need subsolvers to optimize the master and subproblems.
    # We relax the master formulation.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    ctx = TestColGenIterationContext(
        ClA.ColGenContext(reform, ClA.ColumnGeneration()),
        master_lp_primal_sol,
        master_lp_dual_sol,
        master_obj_val,
        pricing_var_reduced_costs,
    )

    output = ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase3(), env)
    @test output.mlp ≈ 79.666666667
    @test output.db ≈ 21.3333333333
    @test output.nb_new_cols == 2
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
#register!(unit_tests, "colgen_default", test_colgen_iteration_min_gap)

function test_colgen_iteration_max_gap()
    env, master, sps, reform = max_toy_gap()

    @show master
    @show sps

end
#register!(unit_tests, "colgen_default", test_colgen_iteration_max_gap)

function test_colgen_iteration_pure_master_vars()
    env, master, sps, reform = toy_gap_with_penalties()

    master_lp_primal_sol = Dict(
        "MC_41" => 1,
        "MC_42" => 1,
        "y_2" => 1,
    )
    master_lp_dual_sol = Dict(
        "c1" => 8.26666667,
        "c2" => 17.13333333,
        "c3" => 18.56666667,
        "c4" => 21.0,
        "c5" => 17.86666667,
        "c6" => 15.41666667,
        "c7" => 19.26666667,
        "c8" => -10.86666667
    )
    master_obj_val = 52.95 

    pricing_var_reduced_costs = Dict(
        "x_11" => 0.26666666999999933,
        "x_12" => - 12.13333333,
        "x_13" => - 7.56666667,
        "x_14" => 0.0,
        "x_15" => - 11.86666667,
        "x_16" => - 10.41666667,
        "x_17" => - 0.26666666999999933,
        "PricingSetupVar_sp_5" => 0.0,
        "x_21" => - 7.266666669999999,
        "x_22" => - 5.133333329999999,
        "x_23" => - 7.56666667,
        "x_24" => - 9.0,
        "x_25" => - 3.8666666700000007,
        "x_26" => - 7.41666667,
        "x_27" => - 14.26666667,
        "PricingSetupVar_sp_4" => 0.0,
    )

    # We need subsolvers to optimize the master and subproblems.
    # We relax the master formulation.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    ctx = TestColGenIterationContext(
        ClA.ColGenContext(reform, ClA.ColumnGeneration()),
        master_lp_primal_sol,
        master_lp_dual_sol,
        master_obj_val,
        pricing_var_reduced_costs,
    )

    output = ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase3(), env)
    @test output.mlp ≈ 52.9500
    @test output.db ≈ 51.5000
    @test output.nb_new_cols == 1
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_default", test_colgen_iteration_pure_master_vars)

function test_colgen_iteration_obj_const()
    env, master, sps, reform = toy_gap_with_obj_const()

    @show master
    @show env
end
#register!(unit_tests, "colgen_default", test_colgen_iteration_obj_const)



#         master
#             min
#             7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45 + 28λ1 + 25λ2 + 21λ3 + 19λ4 + 22λ5 + 18λ6 + 28λ7
#             s.t.
#             x_12 + x_13 + x_14 + x_15 + 2λ1 + 2λ2 + 2λ3 + 2λ4 + 2λ5 + 2λ6 + 2λ7 == 2
#             x_12 + x_23 + x_24 + x_25 + 2λ1 + 2λ2 + 2λ3 + 1λ4 + 1λ5 + 2λ6 + 3λ7 == 2
#             x_13 + x_23 + x_34 + x_35 + 2λ1 + 3λ2 + 2λ3 + 3λ4 + 2λ5 + 3λ6 + 1λ7 == 2
#             x_14 + x_24 + x_34 + x_45 + 2λ1 + 2λ2 + 3λ3 + 3λ4 + 3λ5 + 1λ6 + 1λ7 == 2
#             x_15 + x_25 + x_35 + x_45 + 2λ1 + 1λ2 + 1λ3 + 1λ4 + 2λ5 + 2λ6 + 3λ7 == 2

#         dw_sp
#             min
#             7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45
#             s.t.
#             x_12 + x_13 + x_14 + x_15 == 1

#         continuous
#             columns
#                 λ1, λ2, λ3, λ4, λ5, λ6, λ7

#         integer
#             representatives
#                 x_12, x_13, x_14, x_15, x_23, x_24, x_25, x_34, x_35, x_45

#         bounds
#             λ1 >= 0
#             λ2 >= 0
#             λ3 >= 0
#             λ4 >= 0
#             λ5 >= 0
#             λ6 >= 0
#             λ7 >= 0
#             x_12 >= 0
#             x_13 >= 0
#             x_14 >= 0
#             x_15 >= 0
#             x_23 >= 0
#             x_24 >= 0
#             x_25 >= 0
#             x_34 >= 0
#             x_35 >= 0
#             x_45 >= 0
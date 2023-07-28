############################################################################################
# Test default implementation of an iteration of Column Generation
############################################################################################
# 1- minimize
# 2- maximize
# 3- minimize with pure master variables
# 4- minimize with objective constant
#
# TODO: description of the tests.
############################################################################################

# Minimization and test all constraint senses
form1() = """
    master
        min
        3x1 + 2x2 + 5x3 + 4y1 + 3y2 + 5y3 + z
        s.t.
        x1 + x2 + x3 + y1 + y2 + y3 + 2z >= 10
        x1 + 2x2     + y1 + 2y2     + z <= 100
        x1 +     3x3 + y1 +    + 3y3    == 100
                                      z <= 5   

    dw_sp
        min
        x1 + x2 + x3 + y1 + y2 + y3
        s.t.
        x1 + x2 + x3 + y1 + y2 + y3 >= 10
        
        integer
            representatives
                x1, x2, x3, y1, y2, y3

            pure
                z
        
        bounds
            x1 >= 0
            x2 >= 0
            x3 >= 0
            y1 >= 0
            y2 >= 0
            y3 >= 0
            z >= 0
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
    @test helper.dw_subprob_c[vids["x1"]] == 3
    @test helper.dw_subprob_c[vids["x2"]] == 2
    @test helper.dw_subprob_c[vids["x3"]] == 5
    @test helper.dw_subprob_c[vids["y1"]] == 4
    @test helper.dw_subprob_c[vids["y2"]] == 3
    @test helper.dw_subprob_c[vids["y3"]] == 5
    @test helper.dw_subprob_c[vids["z"]] == 0

    @test helper.dw_subprob_A[cids["c1"], vids["x1"]] == 1
    @test helper.dw_subprob_A[cids["c1"], vids["x2"]] == 1
    @test helper.dw_subprob_A[cids["c1"], vids["x3"]] == 1
    @test helper.dw_subprob_A[cids["c1"], vids["y1"]] == 1
    @test helper.dw_subprob_A[cids["c1"], vids["y2"]] == 1
    @test helper.dw_subprob_A[cids["c1"], vids["y3"]] == 1
    @test helper.dw_subprob_A[cids["c1"], vids["z"]] == 0  # z is not in the subproblem.

    @test helper.dw_subprob_A[cids["c2"], vids["x1"]] == 1
    @test helper.dw_subprob_A[cids["c2"], vids["x2"]] == 2
    @test helper.dw_subprob_A[cids["c2"], vids["y1"]] == 1
    @test helper.dw_subprob_A[cids["c2"], vids["y2"]] == 2
    @test helper.dw_subprob_A[cids["c2"], vids["z"]] == 0 # z is not in the subproblem.

    @test helper.dw_subprob_A[cids["c3"], vids["x1"]] == 1
    @test helper.dw_subprob_A[cids["c3"], vids["x3"]] == 3
    @test helper.dw_subprob_A[cids["c3"], vids["y1"]] == 1
    @test helper.dw_subprob_A[cids["c3"], vids["y3"]] == 3
    @test helper.dw_subprob_A[cids["c3"], vids["z"]] == 0 # z is not in the subproblem.

    @test helper.master_c[vids["x1"]] == 0 # x1 is not in the master.
    @test helper.master_c[vids["x2"]] == 0 # x2 is not in the master.
    @test helper.master_c[vids["x3"]] == 0 # x3 is not in the master.
    @test helper.master_c[vids["y1"]] == 0 # y1 is not in the master.
    @test helper.master_c[vids["y2"]] == 0 # y2 is not in the master.
    @test helper.master_c[vids["y3"]] == 0 # y3 is not in the master.
    @test helper.master_c[vids["z"]] == 1

    @test helper.master_A[cids["c1"], vids["x1"]] == 0 # x1 is not in the master.
    @test helper.master_A[cids["c1"], vids["z"]] == 2
    @test helper.master_A[cids["c2"], vids["z"]] == 1
    @test helper.master_A[cids["c3"], vids["z"]] == 0
    @test helper.master_A[cids["c4"], vids["z"]] == 1
end
register!(unit_tests, "colgen_default", test_reduced_costs_calculation_helper)


# Minimization and test all constraint senses
form2() = """
    master
        min
        3x1 + 2x2 + 5x3 + 4y1 + 3y2 + 5y3 + z1 + z2
        s.t.
        x1 + x2 + x3 + y1 + y2 + y3 + 2z1 + z2 >= 10
        x1 + 2x2     + y1 + 2y2     + z1       <= 100
        x1 +     3x3 + y1 +    + 3y3           == 100
                                      z1  + z2 <= 5  

    dw_sp
        min
        x1 + x2 + x3 + y1 + y2 + y3
        s.t.
        x1 + x2 + x3 + y1 + y2 + y3 >= 10
        
        integer
            representatives
                x1, x2, x3, y1, y2, y3

            pure
                z1, z2
        
        bounds
            x1 >= 0
            x2 >= 0
            x3 >= 0
            y1 >= 0
            y2 >= 0
            y3 >= 0
            z1 >= 0
            z2 >= 3
"""

function test_subgradient_calculation_helper()
    _, master, _, _, _ = reformfromstring(form2())

    vids = get_name_to_varids(master)
    cids = get_name_to_constrids(master)

    helper = ClA.SubgradientCalculationHelper(master)
    @test helper.a[cids["c1"]] == 10
    @test helper.a[cids["c2"]] == -100
    @test helper.a[cids["c3"]] == 100
    @test helper.a[cids["c4"]] == -5

    @test helper.A[cids["c1"], vids["x1"]] == 1
    @test helper.A[cids["c1"], vids["x2"]] == 1
    @test helper.A[cids["c1"], vids["x3"]] == 1
    @test helper.A[cids["c1"], vids["y1"]] == 1
    @test helper.A[cids["c1"], vids["y2"]] == 1
    @test helper.A[cids["c1"], vids["y3"]] == 1
    @test helper.A[cids["c1"], vids["z1"]] == 2
    @test helper.A[cids["c1"], vids["z2"]] == 1
    @test helper.A[cids["c2"], vids["x1"]] == -1
    @test helper.A[cids["c2"], vids["x2"]] == -2
    @test helper.A[cids["c2"], vids["y1"]] == -1
    @test helper.A[cids["c2"], vids["y2"]] == -2
    @test helper.A[cids["c2"], vids["z1"]] == -1
    @test helper.A[cids["c2"], vids["z2"]] == 0
    @test helper.A[cids["c3"], vids["x1"]] == 1
    @test helper.A[cids["c3"], vids["x3"]] == 3
    @test helper.A[cids["c3"], vids["y1"]] == 1
    @test helper.A[cids["c3"], vids["y3"]] == 3
    @test helper.A[cids["c3"], vids["z1"]] == 0
    @test helper.A[cids["c3"], vids["z2"]] == 0
    @test helper.A[cids["c4"], vids["z1"]] == -1
    @test helper.A[cids["c4"], vids["z2"]] == -1
end
register!(unit_tests, "colgen_default", test_subgradient_calculation_helper)

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
    # We introduce variables (z1, z2), (z3, z4) and (z5, z6) to force dual value of constraint c2, c1 and c5 to be equal to 6.0, 3.0 and 22.0 respectively.
    form = """
    master
        max
        - 10000.0 local_art_of_cov_5 - 10000.0 local_art_of_cov_4 - 10000.0 local_art_of_cov_6 - 10000.0 local_art_of_cov_7 - 10000.0 local_art_of_cov_2 - 10000.0 local_art_of_cov_3 - 10000.0 local_art_of_cov_1 - 10000.0 local_art_of_sp_lb_5 - 10000.0 local_art_of_sp_ub_5 - 10000.0 local_art_of_sp_lb_4 - 10000.0 local_art_of_sp_ub_4 - 100000.0 global_pos_art_var - 100000.0 global_neg_art_var + 53.0 MC_30 + 49.0 MC_31 + 35.0 MC_32 + 45.0 MC_33 + 27.0 MC_34 + 42.0 MC_35 + 45.0 MC_36 + 12.0 MC_37 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4 + 6.0 z1 - 6.0 z2 + 3.0 z3 - 3.0 z4 + 22.0 z5 - 22.0 z6
        s.t.
        1.0 x_11 + 1.0 x_21 - 1.0 local_art_of_cov_1 - 1.0 global_neg_art_var + 1.0 MC_30 + 1.0 MC_34 + z3 - z4 <= 1.0
        1.0 x_12 + 1.0 x_22 - 1.0 local_art_of_cov_2 - 1.0 global_neg_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + 1.0 MC_36 + 1.0 MC_37 + z1 - z2 <= 1.0
        1.0 x_13 + 1.0 x_23 - 1.0 local_art_of_cov_3 - 1.0 global_neg_art_var + 1.0 MC_31 + 1.0 MC_32 + 1.0 MC_33 + 1.0 MC_35  <= 1.0
        1.0 x_14 + 1.0 x_24 - 1.0 local_art_of_cov_4 - 1.0 global_neg_art_var + 1.0 MC_30 + 1.0 MC_31 + 1.0 MC_36  <= 1.0 
        1.0 x_15 + 1.0 x_25 - 1.0 local_art_of_cov_5 - 1.0 global_neg_art_var + 1.0 MC_31 + 1.0 MC_33 + 1.0 MC_35 + z5 - z6 <= 1.0 
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
        
        pure
            z1, z2, z3, z4, z5, z6


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
    # We add variables z1 and z2 to fix the dual value of constraint c4 to 21.
    # We add variables z3 and z4 to fix the dual value of constraint c3 to 18.56666667.
    # We add variables z5 and z6 to fix the dual value of constraint c7 to 19.26666667.
    # We add variables z7 and z8 to fix the dual value of constraint c1 to 8.26666667.
    # We add variables z9 and z10 to fix the dual value of constraint c2 to 17.13333333
    form = """
    master
        min
        3.15 y_1 + 5.949999999999999 y_2 + 7.699999999999999 y_3 + 11.549999999999999 y_4 + 7.0 y_5 + 4.55 y_6 + 8.399999999999999 y_7 + 10000.0 local_art_of_cov_5 + 10000.0 local_art_of_cov_4 + 10000.0 local_art_of_cov_6 + 10000.0 local_art_of_cov_7 + 10000.0 local_art_of_cov_2 + 10000.0 local_art_of_limit_pen + 10000.0 local_art_of_cov_3 + 10000.0 local_art_of_cov_1 + 10000.0 local_art_of_sp_lb_5 + 10000.0 local_art_of_sp_ub_5 + 10000.0 local_art_of_sp_lb_4 + 10000.0 local_art_of_sp_ub_4 + 100000.0 global_pos_art_var + 100000.0 global_neg_art_var + 51.0 MC_38 + 38.0 MC_39 + 10.0 MC_40 + 28.0 MC_41 + 19.0 MC_42 + 26.0 MC_43 + 31.0 MC_44 + 42.0 MC_45 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4 + 21 z1 - 21 z2 + 18.56666667 z3 -18.56666667 z4 + 19.26666667 z5 - 19.26666667 z6 + 8.26666667 z7 - 8.26666667 z8 + 17.13333333 z9 - 17.13333333 z10
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 y_1 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43 + z7 - z8 >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 y_2 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_40 + 1.0 MC_44 + 1.0 MC_45 + z9 - z10 >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 y_3 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45 + z3 - z4 >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 y_4 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_44 + z1 - z2 >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 y_5 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43 + 1.0 MC_45  >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 y_6 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 y_7 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_45 + z5 - z6 >= 1.0
        1.0 y_1 + 1.0 y_2 + 1.0 y_3 + 1.0 y_4 + 1.0 y_5 + 1.0 y_6 + 1.0 y_7 - 1.0 local_art_of_limit_pen - 1.0 global_neg_art_var <= 1.0
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
            y_1, y_2, y_3, y_4, y_5, y_6, y_7, z1, z2, z3, z4, z5, z6, z7, z8, z9, z10

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
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 51.0 MC_30 + 38.0 MC_31 + 31.0 MC_32 + 35.0 MC_33 + 48.0 MC_34 + 13.0 MC_35 + 53.0 MC_36 + 28.0 MC_37 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4 + 700.0
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

function check_identical_subproblems()
    # Used to check the output of identical_subproblem. The two formulations should be equivalent. 
    # Subproblem 5 is introduced twice.
    form = """
    master
        min
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 8.0 x_21 + 5.0 x_22 + 11.0 x_23 + 21.0 x_24 + 6.0 x_25 + 5.0 x_26 + 19.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4  
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var >= 1.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 <= 1.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 <= 1.0 {MasterConvexityConstr}

    dw_sp
        min
        8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 0.0 PricingSetupVar_sp_5  
        s.t.
        2.0 x_11 + 3.0 x_12 + 3.0 x_13 + 1.0 x_14 + 2.0 x_15 + 1.0 x_16 + 1.0 x_17  <= 8.0

    dw_sp
        min
        8.0 x_21 + 5.0 x_22 + 11.0 x_23 + 21.0 x_24 + 6.0 x_25 + 5.0 x_26 + 19.0 x_27 + 0.0 PricingSetupVar_sp_4
        s.t.
        2.0 x_21 + 3.0 x_22 + 3.0 x_23 + 1.0 x_24 + 2.0 x_25 + 1.0 x_26 + 1.0 x_27  <= 8.0

    continuous
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
ColGen.is_minimization(ctx::TestColGenIterationContext) = ColGen.is_minimization(ctx.context)
ColGen.get_pricing_subprobs(ctx::TestColGenIterationContext) = ColGen.get_pricing_subprobs(ctx.context)
ColGen.colgen_iteration_output_type(::TestColGenIterationContext) = ClA.ColGenIterationOutput

struct TestColGenStage <: ColGen.AbstractColGenStage end
ColGen.get_pricing_subprob_optimizer(::TestColGenStage, _) = 1

function ColGen.optimize_master_lp_problem!(master, ctx::TestColGenIterationContext, env)
    output = ColGen.optimize_master_lp_problem!(master, ctx.context, env)
    primal_sol = ColGen.get_primal_sol(output)
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

ColGen.check_primal_ip_feasibility!(master_lp_primal_sol, ::TestColGenIterationContext, phase, env) = nothing, false
ColGen.is_unbounded(ctx::TestColGenIterationContext) = ColGen.is_unbounded(ctx.context)
ColGen.is_infeasible(ctx::TestColGenIterationContext) = ColGen.is_infeasible(ctx.context)
ColGen.update_master_constrs_dual_vals!(ctx::TestColGenIterationContext, master_lp_dual_sol) = ColGen.update_master_constrs_dual_vals!(ctx.context, master_lp_dual_sol)
ColGen.update_reduced_costs!(ctx::TestColGenIterationContext, phase, red_costs) = nothing
ColGen.get_subprob_var_orig_costs(ctx::TestColGenIterationContext) = ColGen.get_subprob_var_orig_costs(ctx.context)
ColGen.get_subprob_var_coef_matrix(ctx::TestColGenIterationContext) = ColGen.get_subprob_var_coef_matrix(ctx.context)

function ColGen.update_sp_vars_red_costs!(ctx::TestColGenIterationContext, sp::Formulation{DwSp}, red_costs)
    ColGen.update_sp_vars_red_costs!(ctx.context, sp, red_costs)
    for (_, var) in ClMP.getvars(sp)
        name = ClMP.getname(sp, var)
        @test ctx.pricing_var_reduced_costs[name] ≈ ClMP.getcurcost(sp, var)
    end
    return
end

ColGen.compute_sp_init_pb(ctx::TestColGenIterationContext, sp::Formulation{DwSp}) =  ColGen.compute_sp_init_pb(ctx.context, sp)
ColGen.compute_sp_init_db(ctx::TestColGenIterationContext, sp::Formulation{DwSp}) = ColGen.compute_sp_init_db(ctx.context, sp)
ColGen.set_of_columns(ctx::TestColGenIterationContext) = ColGen.set_of_columns(ctx.context)
ColGen.push_in_set!(ctx::TestColGenIterationContext, set, col) = ColGen.push_in_set!(ctx.context, set, col)

# Columns insertion
function ColGen.insert_columns!(ctx::TestColGenIterationContext, phase, columns)
    return ColGen.insert_columns!(ctx.context, phase, columns)
end

function ColGen.optimize_pricing_problem!(ctx::TestColGenIterationContext, sp::Formulation{DwSp}, env, optimizer, master_dual_sol, stab_changes_mast_dual_sol)
    output = ColGen.optimize_pricing_problem!(ctx.context, sp, env, optimizer, master_dual_sol, stab_changes_mast_dual_sol)
    # test here
    return output
end

function ColGen.compute_dual_bound(ctx::TestColGenIterationContext, phase, sp_dbs, generated_columns, master_dual_sol)
    return ColGen.compute_dual_bound(ctx.context, phase, sp_dbs, generated_columns, master_dual_sol)
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

    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase0(), TestColGenStage(), env, input, Coluna.Algorithm.NoColGenStab())
    @test output.mlp ≈ 79.666666667
    @test output.db ≈ 21.3333333333
    @test output.nb_new_cols == 2
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_default", test_colgen_iteration_min_gap)

function test_colgen_iteration_max_gap()
    env, master, sps, reform = max_toy_gap()
    
    master_lp_primal_sol = Dict(
        "MC_30" => 0.5,
        "MC_31" => 0.5,
        "MC_33" => 0.5,
        "MC_34" => 0.5,
    )
    master_lp_dual_sol = Dict(
        "c1" => 3.0, # fixed
        "c2" => 6.0, # fixed
        "c4" => 15.0,
        "c5" => 22.0, # fixed
        "c6" => 11.0,
        "c7" => 8.0,
        "c9" => 16.0,
        "c11" => 6.0
    )
    master_obj_val = 87.00

    pricing_var_reduced_costs = Dict(
        "x_11" => 5.0,
        "x_12" => - 1.0,
        "x_13" => 11.0,
        "x_14" => 6.0,
        "x_15" => - 16.0,
        "x_16" => - 6.0,
        "x_17" => 11.0,
        "PricingSetupVar_sp_5" => 0.0,
        "x_21" => - 2.0,
        "x_22" => 6.0,
        "x_23" => 11.0,
        "x_24" => - 3.0,
        "x_25" => - 8.0,
        "x_26" => - 3.0,
        "x_27" => - 3.0,
        "PricingSetupVar_sp_4" => 0.0,
    )

    ctx = TestColGenIterationContext(
        ClA.ColGenContext(reform, ClA.ColumnGeneration()),
        master_lp_primal_sol,
        master_lp_dual_sol,
        master_obj_val,
        pricing_var_reduced_costs,
    )
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase0(), TestColGenStage(), env, input, Coluna.Algorithm.NoColGenStab())
    @test output.mlp ≈ 87.00
    @test output.db ≈ 110.00
    @test output.nb_new_cols == 2
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_default", test_colgen_iteration_max_gap)

function test_colgen_iteration_pure_master_vars()
    env, master, sps, reform = toy_gap_with_penalties()

    master_lp_primal_sol = Dict(
        "MC_41" => 1,
        "MC_42" => 1,
        "y_2" => 1,
    )
    master_lp_dual_sol = Dict(
        "c1" => 8.26666667, # fixed
        "c2" => 17.13333333,  # fixed
        "c3" => 18.56666667,  # fixed
        "c4" => 21.0,  # fixed
        "c5" => 17.86666667,
        "c6" => 15.41666667,
        "c7" => 19.26666667,  # fixed
        "c8" => -10.86666667,
        "c10" => -22.55,
        "c12" => -30.83333334
    )
    master_obj_val = 52.95 

    pricing_var_reduced_costs = Dict(
        "x_11" => - 0.26666666999999933,
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

    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase0(), TestColGenStage(), env, input, Coluna.Algorithm.NoColGenStab())
    @test output.mlp ≈ 52.9500
    @test output.db ≈ 51.5
    @test output.nb_new_cols == 1
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_default", test_colgen_iteration_pure_master_vars)

function test_colgen_iteration_obj_const()
    env, master, sps, reform = toy_gap_with_obj_const()
    master_lp_primal_sol = Dict(
        "MC_30" => 1/3,
        "MC_31" => 2/3,
        "MC_32" => 1/3,
        "MC_36" => 1/3,
        "MC_37" => 1/3,
    )
    master_lp_dual_sol = Dict(
        "c1" => 11.33333333,
        "c3" => 17.33333333,
        "c5" => 9.33333333,
        "c6" => 31.0,
        "c7" => 10.66666667,
    )
    master_obj_val = 779.67

    pricing_var_reduced_costs = Dict(
        "x_11" => - 3.3333333300000003,
        "x_12" => 5.0,
        "x_13" => - 6.3333333299999985,
        "x_14" => 21.0,
        "x_15" => - 3.3333333300000003,
        "x_16" => - 26.0,
        "x_17" => 8.33333333,
        "PricingSetupVar_sp_5" => 0.0,
        "x_21" => - 10.33333333,
        "x_22" => 12.0,
        "x_23" => - 6.3333333299999985,
        "x_24" => 12.0,
        "x_25" => 4.66666667,
        "x_26" => - 23.0,
        "x_27" => - 5.66666667,
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

    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase0(), TestColGenStage(), env, input, Coluna.Algorithm.NoColGenStab())
   
    @test output.mlp ≈ 779.6666666666667 
    @test output.db ≈ 717.6666666766668
    @test output.nb_new_cols == 2
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false

end
register!(unit_tests, "colgen_default", test_colgen_iteration_obj_const)

############################################################################################
# Test column insertion
############################################################################################

function insert_cols_form()
    # We introduce variables z1 & z2 to force dual value of constraint c7 to equal to 28.
    form = """
    master
        min
        x1 + x2 + x3 + x4 + x5
        s.t.
        x1 + x2 + x3 + x4 + x5 >= 0.0

    dw_sp
        min
        x1 + x2 + x3 + x4 + x5

    continuous
        representatives
            x1, x2, x3, x4, x5
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_two_identicals_cols_at_two_iterations_failure()
    env, master, sps, reform = insert_cols_form()
    spform = sps[1]
    spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
    phase = ClA.ColGenPhase0()

    ## Iteration 1
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration(
        throw_column_already_inserted_warning = true
    ))

    redcosts_spsols = [-2.0, 2.0]
    col1 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        1.0,
        ClB.FEASIBLE_SOL
    )
    col2 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x2", "x3"]),
        [5.0, 2.0],
        2.5,
        ClB.FEASIBLE_SOL
    ) # not inserted because positive reduced cost.

    columns = ColGen.set_of_columns(ctx)
    for (cost, sol) in Iterators.zip(redcosts_spsols, [col1, col2])
        ColGen.push_in_set!(ctx, columns, ClA.GeneratedColumn(sol, cost))
    end

    new_cols = ColGen.insert_columns!(ctx, phase, columns)
    @test length(new_cols) == 1

    ## Iteration 2
    redcosts_spsols = [-1.0]
    col3 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        3.0,
        ClB.FEASIBLE_SOL
    )

    columns = ColGen.set_of_columns(ctx)
    for (cost, sol) in Iterators.zip(redcosts_spsols, [col3])
        ColGen.push_in_set!(ctx, columns, ClA.GeneratedColumn(sol, cost))
    end
    @test_throws ClA.ColumnAlreadyInsertedColGenWarning ColGen.insert_columns!(ctx, phase, columns)
end
register!(unit_tests, "colgen_default", test_two_identicals_cols_at_two_iterations_failure)

function test_two_identicals_cols_at_same_iteration_ok()
    env, master, sps, reform = insert_cols_form()
    spform = sps[1]
    spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
    phase = ClA.ColGenPhase0()

    redcosts_spsols = [-2.0, -2.0, 2.0]
    col1 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        1.0,
        ClB.FEASIBLE_SOL
    )
    col2 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        2.0,
        ClB.FEASIBLE_SOL
    )
    col3 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x2", "x3"]),
        [5.0, 2.0],
        3.5,
        ClB.FEASIBLE_SOL
    ) # not inserted because positive reduced cost.

    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration(
        throw_column_already_inserted_warning = true
    ))

    columns = ColGen.set_of_columns(ctx)
    for (cost, sol) in Iterators.zip(redcosts_spsols, [col1, col2, col3])
        ColGen.push_in_set!(ctx, columns, ClA.GeneratedColumn(sol, cost))
    end

    new_cols = ColGen.insert_columns!(ctx, phase, columns)
    @test length(new_cols) == 2
end
register!(unit_tests, "colgen_default", test_two_identicals_cols_at_same_iteration_ok)

function test_deactivated_column_added_twice_at_same_iteration_ok()
    env, master, sps, reform = insert_cols_form()
    spform = sps[1]
    spvarids = Dict(CL.getname(spform, var) => varid for (varid, var) in CL.getvars(spform))
    phase = ClA.ColGenPhase0()

    ## Add column.
    col1 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        1.0,
        ClB.FEASIBLE_SOL
    )
    col_id = ClMP.insert_column!(master, col1, "MC")
    
    ## Deactivate column.
    ClMP.deactivate!(master, col_id)

    redcosts_spsols = [-2.0, -2.0]
    col2 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        1.0,
        ClB.FEASIBLE_SOL
    )
    col3 = ClMP.PrimalSolution(
        spform, 
        map(x -> spvarids[x], ["x1", "x3"]),
        [1.0, 2.0],
        2.0,
        ClB.FEASIBLE_SOL
    )

    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration(
        throw_column_already_inserted_warning = true
    ))

    columns = ColGen.set_of_columns(ctx)
    for (cost, sol) in Iterators.zip(redcosts_spsols, [col2, col3])
        ColGen.push_in_set!(ctx, columns, ClA.GeneratedColumn(sol, cost))
    end

    new_cols = ColGen.insert_columns!(ctx, phase, columns)
    @test length(new_cols) == 1
end
register!(unit_tests, "colgen_default", test_deactivated_column_added_twice_at_same_iteration_ok)

############################################################################################
# Test the column generation loop
############################################################################################
function min_toy_gap_for_colgen_loop()
    form = """
    master
        min
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var >= 1.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 <= 1.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 <= 1.0 {MasterConvexityConstr}

    dw_sp
        min
        8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 0.0 PricingSetupVar_sp_5 
        s.t.
        2.0 x_11 + 3.0 x_12 + 3.0 x_13 + 1.0 x_14 + 2.0 x_15 + 1.0 x_16 + 1.0 x_17  <= 5.0

    dw_sp
        min
        1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_4
        s.t.
        5.0 x_21 + 1.0 x_22 + 1.0 x_23 + 3.0 x_24 + 1.0 x_25 + 5.0 x_26 + 4.0 x_27  <= 8.0

    continuous
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
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_colgen_loop()
    env, master, sps, reform = min_toy_gap_for_colgen_loop()
    # We need subsolvers to optimize the master and subproblems.
    # We relax the master formulation.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    phase = ClA.ColGenPhase0()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    ColGen.setup_reformulation!(reform, phase)
    Coluna.set_optim_start_time!(env)
    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run_colgen_phase!(ctx, phase, ColGenIterationTestStage(), env, input, Coluna.Algorithm.NoColGenStab())

    # EXPECTED:
    #    """
    #   <it= 11> <et=19.92> <mst= 0.00> <sp= 0.00> <cols= 0> <al= 0.00> <DB=   70.3333> <mlp=   70.3333> <PB=89.0000>
    # [ Info: Column generation algorithm has converged.
    # """

    @test output.mlp ≈ 70.33333333
    @test output.db ≈ 70.33333333
    @test Coluna.ColunaBase.getvalue(output.master_ip_primal_sol) ≈ 89.0
    return
end
register!(unit_tests, "colgen_default", test_colgen_loop)


function min_toy_gap_for_colgen()
    # We use very large costs to go through phase 1.
    form = """
    master
        min
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 100.0 local_art_of_sp_lb_4 + 100.0 local_art_of_sp_ub_4 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 800.0 x_11 + 500.0 x_12 + 1100.0 x_13 + 2100.0 x_14 + 600.0 x_15 + 500.0 x_16 + 1900.0 x_17 + 100.0 x_21 + 1200.0 x_22 + 1100.0 x_23 + 1200.0 x_24 + 1400.0 x_25 + 800.0 x_26 + 500.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var >= 1.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 <= 1.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 <= 1.0 {MasterConvexityConstr}

    dw_sp
        min
        800.0 x_11 + 500.0 x_12 + 1100.0 x_13 + 2100.0 x_14 + 600.0 x_15 + 500.0 x_16 + 1900.0 x_17 + 0.0 PricingSetupVar_sp_5 
        s.t.
        2.0 x_11 + 3.0 x_12 + 3.0 x_13 + 1.0 x_14 + 2.0 x_15 + 1.0 x_16 + 1.0 x_17  <= 5.0

    dw_sp
        min
        100.0 x_21 + 1200.0 x_22 + 1100.0 x_23 + 1200.0 x_24 + 1400.0 x_25 + 800.0 x_26 + 500.0 x_27 + 0.0 PricingSetupVar_sp_4
        s.t.
        5.0 x_21 + 1.0 x_22 + 1.0 x_23 + 3.0 x_24 + 1.0 x_25 + 5.0 x_26 + 4.0 x_27  <= 8.0

    continuous
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
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_identical_subproblems()
    env, master, sps, reform = identical_subproblems()
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())

    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run!(ctx, env, input)
    @test output.mlp ≈ 75
    @test output.mlp ≈ 75
end
register!(unit_tests, "colgen_default", test_identical_subproblems)

# Don't run this test because we use it to check the output of the previous test.
function expected_output_identical_subproblems()
    env, master, sps, reform = check_identical_subproblems()
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    
    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run!(ctx, env, input)
    @test output.mlp ≈ 75
    @test output.db ≈ 75
end
register!(unit_tests, "colgen_default", expected_output_identical_subproblems; x = true)

function test_colgen()
    env, master, sps, reform = min_toy_gap_for_colgen()
    # We need subsolvers to optimize the master and subproblems.
    # We relax the master formulation.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    Coluna.set_optim_start_time!(env)
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())

    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run!(ctx, env, input)
    @test output.mlp ≈ 7033.3333333
    @test output.db ≈ 7033.3333333
end
register!(unit_tests, "colgen", test_colgen)

function identical_subproblems()
    form = """
    master
        min
        100.0 local_art_of_cov_5 + 100.0 local_art_of_cov_4 + 100.0 local_art_of_cov_6 + 100.0 local_art_of_cov_7 + 100.0 local_art_of_cov_2 + 100.0 local_art_of_cov_3 + 100.0 local_art_of_cov_1 + 100.0 local_art_of_sp_lb_5 + 100.0 local_art_of_sp_ub_5 + 1000.0 global_pos_art_var + 1000.0 global_neg_art_var + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 0.0 PricingSetupVar_sp_5 
        s.t.
        1.0 x_11 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var >= 1.0
        1.0 x_12 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var >= 1.0
        1.0 x_13 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var >= 1.0
        1.0 x_14 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var >= 1.0
        1.0 x_15 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var >= 1.0
        1.0 x_16 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var >= 1.0
        1.0 x_17 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var >= 1.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 <= 2.0 {MasterConvexityConstr}

    dw_sp
        min
        8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 0.0 PricingSetupVar_sp_5  
        s.t.
        2.0 x_11 + 3.0 x_12 + 3.0 x_13 + 1.0 x_14 + 2.0 x_15 + 1.0 x_16 + 1.0 x_17  <= 8.0

    continuous
        artificial
            local_art_of_cov_5, local_art_of_cov_4, local_art_of_cov_6, local_art_of_cov_7, local_art_of_cov_2, local_art_of_cov_3, local_art_of_cov_1, local_art_of_sp_lb_5, local_art_of_sp_ub_5, global_pos_art_var, global_neg_art_var

    integer
        pricing_setup
            PricingSetupVar_sp_5

    binary
        representatives
            x_11, x_12, x_13, x_14, x_15, x_16, x_17

    bounds
        0.0 <= x_11 <= 1.0
        0.0 <= x_12 <= 1.0
        0.0 <= x_13 <= 1.0
        0.0 <= x_14 <= 1.0
        0.0 <= x_15 <= 1.0
        0.0 <= x_16 <= 1.0
        0.0 <= x_17 <= 1.0
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
        global_pos_art_var >= 0.0
        global_neg_art_var >= 0.0
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function r1c_form()

    form = """
    master
        min
        1.0 MC_1 + 1.0 MC_2 + 1.0 MC_3 + 1.0 MC_4 + 1.0 MC_5 + 8.0 x_1 + 1.0 x_2 + 3.0 x_3 + 11.0 x_4 + 7.0 x_5 
        s.t.
        1.0 MC_1 + 1.0 MC_2 + 1.0 MC_4 + 1.0 x_1 >= 1.0
        1.0 MC_1 + 1.0 MC_2 + 1.0 MC_4 + 1.0 MC_5 + 1.0 x_2 >= 1.0
        1.0 MC_2 + 1.0 MC_3 + 1.0 MC_5 + 1.0 x_3 >= 1.0
        1.0 MC_3 + 1.0 MC_4 + 1.0 MC_5 + 1.0 x_4 >= 1.0
        1.0 MC_3 + 1.0 MC_4 + 1.0 MC_5 + 1.0 x_5 >= 1.0
        0.0 MC_1 + 1.0 MC_2 + 1.0 MC_3 + 1.0 MC_4 + 1.0 MC_5 <= 1.0

    dw_sp
        min
        8.0 x_1 + 1.0 x_2 + 3.0 x_3 + 11.0 x_4 + 7.0 x_5 
        s.t.
        2.0 x_1 + 3.0 x_2 + 3.0 x_3 <= 8.0 

    continuous
        columns
            MC_1, MC_2, MC_3, MC_4, MC_5
    
    binary
        representatives
            x_1, x_2, x_3, x_4, x_5

    bounds
        0.0 <= x_1 <= 1.0
        0.0 <= x_2 <= 1.0
        0.0 <= x_3 <= 1.0
        0.0 <= x_4 <= 1.0
        0.0 <= x_5 <= 1.0
        MC_1 >= 0.0 
        MC_2 >= 0.0
        MC_3 >= 0.0
        MC_4 >= 0.0
        MC_5 >= 0.0
    """

    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_red_cost_calc_with_non_robust_cuts()
    var_costs = [
        8.0,
        1.0,
        3.0,
        11.0,
        7.0
    ]

    A = [
        1 0 0 0 0;
        0 1 0 0 0;
        0 0 1 0 0;
        0 0 0 1 0;
        0 0 0 0 1;
        0 0 0 0 0
    ]

    constr_costs = [2.0, 8.0, 1.0, 3.0, 9.0, 4.0]

    expected_redcosts = var_costs - transpose(A) * constr_costs

    form = r1c_form()
    env, master, sps, reform = form

    constrids = Dict(getname(master, id) => id for (id,_) in ClA.getconstrs(master))
    varids = Dict(getname(master, id) => id for (id,_) in ClA.getvars(master))

    dual_sol = ClA.DualSolution(
        master,
        map(name -> constrids[name], ["c1", "c2", "c3", "c4", "c5", "c6"]),
        constr_costs,
        [], 
        [], 
        [], 
        0.0,
        FEASIBLE_SOL
    )

    helper = ClA.ReducedCostsCalculationHelper(master)

    coeffs =  transpose(helper.dw_subprob_A) * dual_sol
    redcosts = helper.dw_subprob_c - coeffs
    
    @test redcosts[varids["x_1"]] == expected_redcosts[1]
    @test redcosts[varids["x_2"]] == expected_redcosts[2]
    @test redcosts[varids["x_3"]] == expected_redcosts[3]
    @test redcosts[varids["x_4"]] == expected_redcosts[4]
    @test redcosts[varids["x_5"]] == expected_redcosts[5]
end
register!(unit_tests, "colgen", test_red_cost_calc_with_non_robust_cuts)


function unbounded_subproblem_form()
    form = """
    master
        min
        x1 + 7x2 + 2x3 + 3x4 + 100 local_art_of_cov_1 + 100 local_art_of_cov_2 + 100 local_art_of_cov_3 + 100 global_pos_art_var + 100 local_art_of_sp_lb_5 + 100 local_art_of_sp_ub_5 + 0 PricingSetupVar_sp_5
        s.t.
        4x1 + 2x2 + 2x3 + 3x4 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var <= 30
        x1 + x2 + x3 + 2x4 + 1.0 local_art_of_cov_2 - 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var == 15
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 <= 2.0 {MasterConvexityConstr}

    dw_sp
        min
        x1 + 7x2 + 2x3 + 3x4 + 0 PricingSetupVar_sp_5
        s.t.
        2x1 + 3x2 - 7x3 - 6x4 == 0
        -x2 + 2x3 <= 0
        x2 - 2x3 - 2x4 <= 0
        -x2 + 3x3 + 2x4 <= 2

    continuous
        representatives
            x1, x2, x3, x4

        artificial
            local_art_of_cov_1, local_art_of_cov_2, local_art_of_cov_3, global_pos_art_var, local_art_of_sp_lb_5, local_art_of_sp_ub_5

    integer
        pricing_setup
            PricingSetupVar_sp_5
        
    bounds
        x1 >= 0.0
        x2 >= 0.0
        x3 >= 0.0
        x4 >= 0.0
        local_art_of_cov_1 >= 0.0
        local_art_of_cov_2 >= 0.0
        local_art_of_cov_3 >= 0.0
        global_pos_art_var >= 0.0
        local_art_of_sp_lb_5 >= 0.0
        local_art_of_sp_ub_5 >= 0.0
        1.0 <= PricingSetupVar_sp_5 <= 1.0
    """
    env, master, sps, _, reform = reformfromstring(form)
    return env, master, sps, reform
end

function test_colgen_unbounded_sp()
    env, master, sps, reform = unbounded_subproblem_form()
    # We need subsolvers to optimize the master and subproblems.
    # We relax the master formulation.
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer())) # we need warm start
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end

    Coluna.set_optim_start_time!(env)
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())

    input = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    output = ColGen.run!(ctx, env, input)
    @show output
end
register!(unit_tests, "colgen", test_colgen_unbounded_sp)
function presolve_toy_gap_with_penalties()
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
    return reform
end

function build_dw_presolve_reformulation()
    for _ in 1:20
        println("\e[44m __________ \e[00m")
    end
    reform = presolve_toy_gap_with_penalties()
    Coluna.Algorithm.create_presolve_reform(reform)
end
register!(unit_tests, "presolve_reformulation", build_dw_presolve_reformulation; f = true)


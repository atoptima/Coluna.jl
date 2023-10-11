function presolve_toy_gap_with_penalties()
    form = """
    master
        min
        3.15 y_1 + 5.949999999999999 y_2 + 7.699999999999999 y_3 + 11.549999999999999 y_4 + 7.0 y_5 + 4.55 y_6 + 8.399999999999999 y_7 + 10000.0 local_art_of_cov_5 + 10000.0 local_art_of_cov_4 + 10000.0 local_art_of_cov_6 + 10000.0 local_art_of_cov_7 + 10000.0 local_art_of_cov_2 + 10000.0 local_art_of_limit_pen + 10000.0 local_art_of_cov_3 + 10000.0 local_art_of_cov_1 + 10000.0 local_art_of_sp_lb_5 + 10000.0 local_art_of_sp_ub_5 + 10000.0 local_art_of_sp_lb_4 + 10000.0 local_art_of_sp_ub_4 + 100000.0 global_pos_art_var + 100000.0 global_neg_art_var + 51.0 MC_38 + 38.0 MC_39 + 10.0 MC_40 + 28.0 MC_41 + 19.0 MC_42 + 26.0 MC_43 + 31.0 MC_44 + 42.0 MC_45 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 y_1 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43  >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 y_2 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_40 + 1.0 MC_44 + 1.0 MC_45 >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 y_3 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45 >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 y_4 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_44  >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 y_5 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43 + 1.0 MC_45  >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 y_6 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 y_7 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_45  >= 1.0
        1.0 y_1 + 1.0 y_2 + 1.0 y_3 + 1.0 y_4 + 1.0 y_5 + 1.0 y_6 + 1.0 y_7 - 1.0 local_art_of_limit_pen - 1.0 global_neg_art_var <= 2.0
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
        0.1 <= y_1 <= 1.1 
        0.2 <= y_2 <= 1.2
        0.3 <= y_3 <= 1.3
        0.4 <= y_4 <= 1.4
        0.5 <= y_5 <= 1.5
        0.6 <= y_6 <= 1.6
        0.7 <= y_7 <= 1.7
"""
    env, master, sps, _, reform = reformfromstring(form)

    return reform, master, sps
end

function build_dw_presolve_reformulation()
    reform, master, sps = presolve_toy_gap_with_penalties()
    presolve_reform = Coluna.Algorithm.create_presolve_reform(reform)

    presolve_original_master = presolve_reform.original_master
    mast_var_ids = Dict{String, Int}(ClMP.getname(master, var) => k for (k, var) in enumerate(presolve_original_master.col_to_var))
    
    var_ids_lbs_ubs = [
        (mast_var_ids["y_1"], 0.1, 1.1),
        (mast_var_ids["y_2"], 0.2, 1.2),
        (mast_var_ids["y_3"], 0.3, 1.3),
        (mast_var_ids["y_4"], 0.4, 1.4),
        (mast_var_ids["y_5"], 0.5, 1.5),
        (mast_var_ids["y_6"], 0.6, 1.6),
        (mast_var_ids["y_7"], 0.7, 1.7),
        (mast_var_ids["x_11"], 0.0, 1.0),
        (mast_var_ids["x_12"], 0.0, 1.0),
        (mast_var_ids["x_13"], 0.0, 1.0),
        (mast_var_ids["x_14"], 0.0, 1.0),
        (mast_var_ids["x_15"], 0.0, 1.0),
        (mast_var_ids["x_16"], 0.0, 1.0),
        (mast_var_ids["x_17"], 0.0, 1.0),
        (mast_var_ids["x_21"], 0.0, 1.0),
        (mast_var_ids["x_22"], 0.0, 1.0),
        (mast_var_ids["x_23"], 0.0, 1.0),
        (mast_var_ids["x_24"], 0.0, 1.0),
        (mast_var_ids["x_25"], 0.0, 1.0),
        (mast_var_ids["x_26"], 0.0, 1.0),
        (mast_var_ids["x_27"], 0.0, 1.0)
    ]

    @test presolve_original_master.form.lower_multiplicity == 1
    @test presolve_original_master.form.upper_multiplicity == 1
  
    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_original_master.form.lbs[varuid] == lb
        @test presolve_original_master.form.ubs[varuid] == ub
    end

    mast_constr_ids = Dict{String, Int}(ClMP.getname(master, constr) => k for (k, constr) in enumerate(presolve_original_master.row_to_constr))
    constr_ids_rhs_sense = [
        (mast_constr_ids["c1"], 1.0, ClMP.Greater),
        (mast_constr_ids["c2"], 1.0, ClMP.Greater),
        (mast_constr_ids["c3"], 1.0, ClMP.Greater),
        (mast_constr_ids["c4"], 1.0, ClMP.Greater),
        (mast_constr_ids["c5"], 1.0, ClMP.Greater),
        (mast_constr_ids["c6"], 1.0, ClMP.Greater),
        (mast_constr_ids["c7"], 1.0, ClMP.Greater),
        (mast_constr_ids["c8"], 2.0, ClMP.Less),
    ]

    for (construid, rhs, sense) in constr_ids_rhs_sense
        @test presolve_original_master.form.rhs[construid] == rhs
        @test presolve_original_master.form.sense[construid] == sense
    end

    presolve_restricted_master = presolve_reform.restricted_master

    @test presolve_restricted_master.form.lower_multiplicity == 1
    @test presolve_restricted_master.form.upper_multiplicity == 1

    mast_var_ids = Dict{String, Int}(ClMP.getname(master, var) => k for (k, var) in enumerate(presolve_restricted_master.col_to_var))
   
    var_ids_lbs_ubs = [
        (mast_var_ids["y_1"], 0.1, 1.1),
        (mast_var_ids["MC_38"], 0.0, Inf),
        (mast_var_ids["MC_39"], 0.0, Inf),
        (mast_var_ids["MC_40"], 0.0, Inf),
        (mast_var_ids["MC_41"], 0.0, Inf),
        (mast_var_ids["MC_42"], 0.0, Inf),
        (mast_var_ids["MC_43"], 0.0, Inf),
        (mast_var_ids["MC_44"], 0.0, Inf),
        (mast_var_ids["MC_45"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_5"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_4"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_6"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_7"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_2"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_3"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_1"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_lb_5"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_ub_5"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_lb_4"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_ub_4"], 0.0, Inf),
        (mast_var_ids["global_pos_art_var"], 0.0, Inf),
        (mast_var_ids["global_neg_art_var"], 0.0, Inf),
        (mast_var_ids["local_art_of_limit_pen"], 0.0, Inf),
    ]
    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_restricted_master.form.lbs[varuid] == lb
        @test presolve_restricted_master.form.ubs[varuid] == ub
    end

    mast_constr_ids = Dict{String, Int}(ClMP.getname(master, constr) => k for (k, constr) in enumerate(presolve_restricted_master.row_to_constr))
    constr_ids_rhs_sense = [
        (mast_constr_ids["c1"], 1.0, ClMP.Greater),
        (mast_constr_ids["c2"], 1.0, ClMP.Greater),
        (mast_constr_ids["c3"], 1.0, ClMP.Greater),
        (mast_constr_ids["c4"], 1.0, ClMP.Greater),
        (mast_constr_ids["c5"], 1.0, ClMP.Greater),
        (mast_constr_ids["c6"], 1.0, ClMP.Greater),
        (mast_constr_ids["c7"], 1.0, ClMP.Greater),
        (mast_constr_ids["c8"], 2.0, ClMP.Less),
        (mast_constr_ids["c9"], 0.0, ClMP.Greater),
        (mast_constr_ids["c10"], 1.0, ClMP.Less),
        (mast_constr_ids["c11"], 0.0, ClMP.Greater),
        (mast_constr_ids["c12"], 1.0, ClMP.Less),
    ]

    for (construid, rhs, sense) in constr_ids_rhs_sense
        @test presolve_restricted_master.form.rhs[construid] == rhs
        @test presolve_restricted_master.form.sense[construid] == sense
    end

    # Test coefficient matrix
    restricted_coef_matrix = [
        (mast_constr_ids["c1"], mast_var_ids["y_1"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["local_art_of_cov_1"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["y_2"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["local_art_of_cov_2"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["y_3"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["local_art_of_cov_3"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["y_4"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["local_art_of_cov_4"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["y_5"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["local_art_of_cov_5"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["y_6"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["local_art_of_cov_6"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["y_7"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["local_art_of_cov_7"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_1"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_2"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_3"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_4"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_5"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_6"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_7"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["local_art_of_limit_pen"], -1.0),
        (mast_constr_ids["c8"], mast_var_ids["global_neg_art_var"], -1.0),
        (mast_constr_ids["c9"], mast_var_ids["local_art_of_sp_lb_5"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["local_art_of_sp_ub_5"], -1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["local_art_of_sp_lb_4"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["local_art_of_sp_ub_4"], -1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_45"], 1.0),
    ]

    for (c, v, val) in restricted_coef_matrix
        @test presolve_restricted_master.form.col_major_coef_matrix[c, v] == val
    end

    dw_sp = ClMP.get_dw_pricing_sps(reform)[5]
    presolve_dw_sp = presolve_reform.dw_sps[5]

    @test presolve_dw_sp.form.lower_multiplicity == 0
    @test presolve_dw_sp.form.upper_multiplicity == 1
    
    sp_var_ids = Dict{String, Int}(ClMP.getname(dw_sp, var) => k for (k,var) in enumerate(presolve_dw_sp.col_to_var))

    var_ids_lbs_ubs = [
        (sp_var_ids["x_11"], 0.0, 1.0),
        (sp_var_ids["x_12"], 0.0, 1.0),
        (sp_var_ids["x_13"], 0.0, 1.0),
        (sp_var_ids["x_14"], 0.0, 1.0),
        (sp_var_ids["x_15"], 0.0, 1.0),
        (sp_var_ids["x_16"], 0.0, 1.0),
        (sp_var_ids["x_17"], 0.0, 1.0),
    ]
   
    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_dw_sp.form.lbs[varuid] == lb
        @test presolve_dw_sp.form.ubs[varuid] == ub
    end

    sp_constr_ids = Dict{String, Int}(ClMP.getname(dw_sp, constr) => k for (k, constr) in enumerate(presolve_dw_sp.row_to_constr))
    constr_ids = [
        sp_constr_ids["sp_c2"],
    ]
    constr_rhs = [
        5.0,
    ]
    constr_sense = [
        ClMP.Less,
    ]
    for (k, construid) in enumerate(constr_ids)
        @test presolve_dw_sp.form.rhs[construid] == constr_rhs[k]
        @test presolve_dw_sp.form.sense[construid] == constr_sense[k]
    end

    # Test coefficient matrix
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_11"]] == 2.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_12"]] == 3.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_13"]] == 3.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_14"]] == 1.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_15"]] == 2.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_16"]] == 1.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_17"]] == 1.0
end
register!(unit_tests, "presolve_reformulation", build_dw_presolve_reformulation)

function presolve_toy_gap_with_penalties2()
    form = """
    master
        min
        3.15 y_1 + 5.949999999999999 y_2 + 7.699999999999999 y_3 + 11.549999999999999 y_4 + 7.0 y_5 + 4.55 y_6 + 8.399999999999999 y_7 + 10000.0 local_art_of_cov_5 + 10000.0 local_art_of_cov_4 + 10000.0 local_art_of_cov_6 + 10000.0 local_art_of_cov_7 + 10000.0 local_art_of_cov_2 + 10000.0 local_art_of_limit_pen + 10000.0 local_art_of_cov_3 + 10000.0 local_art_of_cov_1 + 10000.0 local_art_of_sp_lb_5 + 10000.0 local_art_of_sp_ub_5 + 10000.0 local_art_of_sp_lb_4 + 10000.0 local_art_of_sp_ub_4 + 100000.0 global_pos_art_var + 100000.0 global_neg_art_var + 51.0 MC_38 + 38.0 MC_39 + 10.0 MC_40 + 28.0 MC_41 + 19.0 MC_42 + 26.0 MC_43 + 31.0 MC_44 + 42.0 MC_45 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17 + 1.0 x_21 + 12.0 x_22 + 11.0 x_23 + 12.0 x_24 + 14.0 x_25 + 8.0 x_26 + 5.0 x_27 + 0.0 PricingSetupVar_sp_5 + 0.0 PricingSetupVar_sp_4
        s.t.
        1.0 x_11 + 1.0 x_21 + 1.0 y_1 + 1.0 local_art_of_cov_1 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43  >= 1.0
        1.0 x_12 + 1.0 x_22 + 1.0 y_2 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_40 + 1.0 MC_44 + 1.0 MC_45 >= 1.0
        1.0 x_13 + 1.0 x_23 + 1.0 y_3 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45 >= 1.0
        1.0 x_14 + 1.0 x_24 + 1.0 y_4 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_44  >= 1.0
        1.0 x_15 + 1.0 x_25 + 1.0 y_5 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43 + 1.0 MC_45  >= 1.0
        1.0 x_16 + 1.0 x_26 + 1.0 y_6 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 1.0
        1.0 x_17 + 1.0 x_27 + 1.0 y_7 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_45  >= 1.0
        1.0 y_1 + 1.0 y_2 + 1.0 y_3 + 1.0 y_4 + 1.0 y_5 + 1.0 y_6 + 1.0 y_7 - 1.0 local_art_of_limit_pen - 1.0 global_neg_art_var <= 2.0
        1.0 PricingSetupVar_sp_5 + 1.0 local_art_of_sp_lb_5 + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 3.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_5 - 1.0 local_art_of_sp_ub_5 + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  <= 5.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  <= 2.0 {MasterConvexityConstr}

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

    integer
        representatives
            x_11, x_21, x_12, x_22, x_13, x_23, x_14, x_24, x_15, x_25, x_16, x_26, x_17, x_27

    bounds
        0.1 <= x_11 <= 1.0
        0.2 <= x_12 <= 1.0
        0.3 <= x_13 <= 1.0
        0.4 <= x_14 <= 1.0
        0.5 <= x_15 <= 1.0
        0.6 <= x_16 <= 1.0
        0.7 <= x_17 <= 1.0
        0.8 <= x_21 <= 1.0
        0.9 <= x_22 <= 1.0
        1.0 <= x_23 <= 2.0
        1.1 <= x_24 <= 2.0
        1.2 <= x_25 <= 2.0
        1.3 <= x_26 <= 2.0
        1.4 <= x_27 <= 2.0
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
        0.1 <= y_1 <= 1.1 
        0.2 <= y_2 <= 1.2
        0.3 <= y_3 <= 1.3
        0.4 <= y_4 <= 1.4
        0.5 <= y_5 <= 1.5
        0.6 <= y_6 <= 1.6
        0.7 <= y_7 <= 1.7
"""
    env, master, sps, _, reform = reformfromstring(form)

    return reform, master, sps
end

function build_dw_presolve_reformulation2()
    reform, master, sps = presolve_toy_gap_with_penalties2()
    presolve_reform = Coluna.Algorithm.create_presolve_reform(reform)

    presolve_original_master = presolve_reform.original_master
    mast_var_ids = Dict{String, Int}(ClMP.getname(master, var) => k for (k, var) in enumerate(presolve_original_master.col_to_var))
    
    var_ids_lbs_ubs = [
        (mast_var_ids["y_1"], 0.1, 1.1),
        (mast_var_ids["y_2"], 0.2, 1.2),
        (mast_var_ids["y_3"], 0.3, 1.3),
        (mast_var_ids["y_4"], 0.4, 1.4),
        (mast_var_ids["y_5"], 0.5, 1.5),
        (mast_var_ids["y_6"], 0.6, 1.6),
        (mast_var_ids["y_7"], 0.7, 1.7),
        (mast_var_ids["x_11"], 0.1*3, 1.0*5),
        (mast_var_ids["x_12"], 0.2*3, 1.0*5),
        (mast_var_ids["x_13"], 0.3*3, 1.0*5),
        (mast_var_ids["x_14"], 0.4*3, 1.0*5),
        (mast_var_ids["x_15"], 0.5*3, 1.0*5),
        (mast_var_ids["x_16"], 0.6*3, 1.0*5),
        (mast_var_ids["x_17"], 0.7*3, 1.0*5),
        (mast_var_ids["x_21"], 0.8*0, 1.0*2),
        (mast_var_ids["x_22"], 0.9*0, 1.0*2),
        (mast_var_ids["x_23"], 1.0*0, 2.0*2),
        (mast_var_ids["x_24"], 1.1*0, 2.0*2),
        (mast_var_ids["x_25"], 1.2*0, 2.0*2),
        (mast_var_ids["x_26"], 1.3*0, 2.0*2),
        (mast_var_ids["x_27"], 1.4*0, 2.0*2)
    ]

    @test presolve_original_master.form.lower_multiplicity == 1
    @test presolve_original_master.form.upper_multiplicity == 1
  
    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_original_master.form.lbs[varuid] == lb
        @test presolve_original_master.form.ubs[varuid] == ub
    end

    mast_constr_ids = Dict{String, Int}(ClMP.getname(master, constr) => k for (k, constr) in enumerate(presolve_original_master.row_to_constr))
    constr_ids_rhs_sense = [
        (mast_constr_ids["c1"], 1.0, ClMP.Greater),
        (mast_constr_ids["c2"], 1.0, ClMP.Greater),
        (mast_constr_ids["c3"], 1.0, ClMP.Greater),
        (mast_constr_ids["c4"], 1.0, ClMP.Greater),
        (mast_constr_ids["c5"], 1.0, ClMP.Greater),
        (mast_constr_ids["c6"], 1.0, ClMP.Greater),
        (mast_constr_ids["c7"], 1.0, ClMP.Greater),
        (mast_constr_ids["c8"], 2.0, ClMP.Less),
    ]

    for (construid, rhs, sense) in constr_ids_rhs_sense
        @test presolve_original_master.form.rhs[construid] == rhs
        @test presolve_original_master.form.sense[construid] == sense
    end

    presolve_restricted_master = presolve_reform.restricted_master

    @test presolve_restricted_master.form.lower_multiplicity == 1
    @test presolve_restricted_master.form.upper_multiplicity == 1

    mast_var_ids = Dict{String, Int}(ClMP.getname(master, var) => k for (k, var) in enumerate(presolve_restricted_master.col_to_var))
   
    var_ids_lbs_ubs = [
        (mast_var_ids["y_1"], 0.1, 1.1),
        (mast_var_ids["MC_38"], 0.0, Inf),
        (mast_var_ids["MC_39"], 0.0, Inf),
        (mast_var_ids["MC_40"], 0.0, Inf),
        (mast_var_ids["MC_41"], 0.0, Inf),
        (mast_var_ids["MC_42"], 0.0, Inf),
        (mast_var_ids["MC_43"], 0.0, Inf),
        (mast_var_ids["MC_44"], 0.0, Inf),
        (mast_var_ids["MC_45"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_5"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_4"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_6"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_7"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_2"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_3"], 0.0, Inf),
        (mast_var_ids["local_art_of_cov_1"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_lb_5"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_ub_5"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_lb_4"], 0.0, Inf),
        (mast_var_ids["local_art_of_sp_ub_4"], 0.0, Inf),
        (mast_var_ids["global_pos_art_var"], 0.0, Inf),
        (mast_var_ids["global_neg_art_var"], 0.0, Inf),
        (mast_var_ids["local_art_of_limit_pen"], 0.0, Inf),
    ]
    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_restricted_master.form.lbs[varuid] == lb
        @test presolve_restricted_master.form.ubs[varuid] == ub
    end

    mast_constr_ids = Dict{String, Int}(ClMP.getname(master, constr) => k for (k, constr) in enumerate(presolve_restricted_master.row_to_constr))
    constr_ids_rhs_sense = [
        (mast_constr_ids["c1"], 1.0, ClMP.Greater),
        (mast_constr_ids["c2"], 1.0, ClMP.Greater),
        (mast_constr_ids["c3"], 1.0, ClMP.Greater),
        (mast_constr_ids["c4"], 1.0, ClMP.Greater),
        (mast_constr_ids["c5"], 1.0, ClMP.Greater),
        (mast_constr_ids["c6"], 1.0, ClMP.Greater),
        (mast_constr_ids["c7"], 1.0, ClMP.Greater),
        (mast_constr_ids["c8"], 2.0, ClMP.Less),
        (mast_constr_ids["c9"], 3.0, ClMP.Greater),
        (mast_constr_ids["c10"], 5.0, ClMP.Less),
        (mast_constr_ids["c11"], 0.0, ClMP.Greater),
        (mast_constr_ids["c12"], 2.0, ClMP.Less),
    ]

    for (construid, rhs, sense) in constr_ids_rhs_sense
        @test presolve_restricted_master.form.rhs[construid] == rhs
        @test presolve_restricted_master.form.sense[construid] == sense
    end

    # Test coefficient matrix
    restricted_coef_matrix = [
        (mast_constr_ids["c1"], mast_var_ids["y_1"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["local_art_of_cov_1"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["y_2"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["local_art_of_cov_2"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["y_3"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["local_art_of_cov_3"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["y_4"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["local_art_of_cov_4"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["y_5"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["local_art_of_cov_5"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["y_6"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["local_art_of_cov_6"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["y_7"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["local_art_of_cov_7"], 1.0),
        (mast_constr_ids["c7"], mast_var_ids["global_pos_art_var"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_1"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_2"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_3"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_4"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_5"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_6"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["y_7"], 1.0),
        (mast_constr_ids["c8"], mast_var_ids["local_art_of_limit_pen"], -1.0),
        (mast_constr_ids["c8"], mast_var_ids["global_neg_art_var"], -1.0),
        (mast_constr_ids["c9"], mast_var_ids["local_art_of_sp_lb_5"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c9"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["local_art_of_sp_ub_5"], -1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_38"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_40"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_42"], 1.0),
        (mast_constr_ids["c10"], mast_var_ids["MC_44"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["local_art_of_sp_lb_4"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c11"], mast_var_ids["MC_45"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["local_art_of_sp_ub_4"], -1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_39"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_41"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_43"], 1.0),
        (mast_constr_ids["c12"], mast_var_ids["MC_45"], 1.0),
    ]

    for (c, v, val) in restricted_coef_matrix
        @test presolve_restricted_master.form.col_major_coef_matrix[c, v] == val
    end

    dw_sp = ClMP.get_dw_pricing_sps(reform)[5]
    presolve_dw_sp = presolve_reform.dw_sps[5]

    @test presolve_dw_sp.form.lower_multiplicity == 3
    @test presolve_dw_sp.form.upper_multiplicity == 5
    
    sp_var_ids = Dict{String, Int}(ClMP.getname(dw_sp, var) => k for (k,var) in enumerate(presolve_dw_sp.col_to_var))

    var_ids_lbs_ubs = [
        (sp_var_ids["x_11"], 0.1, 1.0),
        (sp_var_ids["x_12"], 0.2, 1.0),
        (sp_var_ids["x_13"], 0.3, 1.0),
        (sp_var_ids["x_14"], 0.4, 1.0),
        (sp_var_ids["x_15"], 0.5, 1.0),
        (sp_var_ids["x_16"], 0.6, 1.0),
        (sp_var_ids["x_17"], 0.7, 1.0),
    ]
   
    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_dw_sp.form.lbs[varuid] == lb
        @test presolve_dw_sp.form.ubs[varuid] == ub
    end

    sp_constr_ids = Dict{String, Int}(ClMP.getname(dw_sp, constr) => k for (k, constr) in enumerate(presolve_dw_sp.row_to_constr))
    constr_ids = [
        sp_constr_ids["sp_c2"],
    ]
    constr_rhs = [
        5.0,
    ]
    constr_sense = [
        ClMP.Less,
    ]
    for (k, construid) in enumerate(constr_ids)
        @test presolve_dw_sp.form.rhs[construid] == constr_rhs[k]
        @test presolve_dw_sp.form.sense[construid] == constr_sense[k]
    end

    # Test coefficient matrix
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_11"]] == 2.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_12"]] == 3.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_13"]] == 3.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_14"]] == 1.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_15"]] == 2.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_16"]] == 1.0
    @test presolve_dw_sp.form.col_major_coef_matrix[sp_constr_ids["sp_c2"], sp_var_ids["x_17"]] == 1.0
end
register!(unit_tests, "presolve_reformulation", build_dw_presolve_reformulation2)

function presolve_reformulation_with_var_not_in_coeff_matrix()
    form = """
    master
        min
        10000.0 local_art_of_cov_5 + 10000.0 local_art_of_cov_4 + 10000.0 local_art_of_cov_6 + 10000.0 local_art_of_cov_7 + 10000.0 local_art_of_cov_2 + 10000.0 local_art_of_cov_3 + 10000.0 local_art_of_cov_1 + 10000.0 local_art_of_sp_lb_4 + 10000.0 local_art_of_sp_ub_4 + 100000.0 global_pos_art_var + 100000.0 global_neg_art_var + 51.0 MC_38 + 38.0 MC_39 + 10.0 MC_40 + 28.0 MC_41 + 19.0 MC_42 + 26.0 MC_43 + 31.0 MC_44 + 42.0 MC_45 + 8.0 x_11 + 5.0 x_12 + 11.0 x_13 + 21.0 x_14 + 6.0 x_15 + 5.0 x_16 + 19.0 x_17  + 0.0 PricingSetupVar_sp_4
        s.t.
        0.0 x_11 + 1.0 x_12 + 1.0 local_art_of_cov_2 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_40 + 1.0 MC_44 + 1.0 MC_45 >= 1.0
        1.0 x_13 + 1.0 local_art_of_cov_3 + 1.0 global_pos_art_var + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45 >= 1.0
        1.0 x_14 + 1.0 local_art_of_cov_4 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_44  >= 1.0
        1.0 x_15 + 1.0 local_art_of_cov_5 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_39 + 1.0 MC_42 + 1.0 MC_43 + 1.0 MC_45  >= 1.0
        1.0 x_16 + 1.0 local_art_of_cov_6 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_40 + 1.0 MC_42 + 1.0 MC_44  >= 1.0
        1.0 x_17 + 1.0 local_art_of_cov_7 + 1.0 global_pos_art_var + 1.0 MC_38 + 1.0 MC_41 + 1.0 MC_45  >= 1.0
        1.0 PricingSetupVar_sp_4 + 1.0 local_art_of_sp_lb_4 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  >= 0.0 {MasterConvexityConstr}
        1.0 PricingSetupVar_sp_4 - 1.0 local_art_of_sp_ub_4 + 1.0 MC_39 + 1.0 MC_41 + 1.0 MC_43 + 1.0 MC_45  <= 1.0 {MasterConvexityConstr}
    
    dw_sp
        min
        x_11 + x_12 + x_13 + x_14 + x_15 + x_16 + x_17 + 0.0 PricingSetupVar_sp_4
        s.t.
        5.0 x_11 + 1.0 x_12 + 1.0 x_13 + 3.0 x_14 + 1.0 x_15 + 5.0 x_16 + 4.0 x_17  <= 8.0

    continuous
        columns
            MC_38, MC_39, MC_40, MC_41, MC_42, MC_43, MC_44, MC_45

        artificial
            local_art_of_cov_5, local_art_of_cov_4, local_art_of_cov_6, local_art_of_cov_7, local_art_of_cov_2, local_art_of_cov_3, local_art_of_cov_1, local_art_of_sp_lb_4, local_art_of_sp_ub_4, global_pos_art_var, global_neg_art_var

    integer
        pricing_setup
            PricingSetupVar_sp_4

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
        1.0 <= PricingSetupVar_sp_4 <= 1.0
        local_art_of_cov_5 >= 0.0
        local_art_of_cov_4 >= 0.0
        local_art_of_cov_6 >= 0.0
        local_art_of_cov_7 >= 0.0
        local_art_of_cov_2 >= 0.0
        local_art_of_cov_3 >= 0.0
        local_art_of_cov_1 >= 0.0
        local_art_of_sp_lb_4 >= 0.0
        local_art_of_sp_ub_4 >= 0.0
        global_pos_art_var >= 0.0
        global_neg_art_var >= 0.0
        MC_38 >= 0
        MC_39 >= 0
        MC_40 >= 0
        MC_41 >= 0
        MC_42 >= 0
        MC_43 >= 0
        MC_44 >= 0
        MC_45 >= 0
"""
    env, master, sps, _, reform = reformfromstring(form)

    return reform, master, sps
end

function build_dw_presolve_reformulation_with_var_not_in_coeff_matrix()
    # We create a reformulation several subproblem variables does not appear in the master problem.
    # x11 does not appear in the coefficient matrix
    reform, master, sps = presolve_reformulation_with_var_not_in_coeff_matrix()
    presolve_reform = Coluna.Algorithm.create_presolve_reform(reform)

    presolve_original_master = presolve_reform.original_master
    mast_var_ids = Dict{String, Int}(ClMP.getname(master, var) => k for (k, var) in enumerate(presolve_original_master.col_to_var))

    var_ids_lbs_ubs = [
        (mast_var_ids["x_11"], 0, 1),
        (mast_var_ids["x_12"], 0, 1),
        (mast_var_ids["x_13"], 0, 1),
        (mast_var_ids["x_14"], 0, 1),
        (mast_var_ids["x_15"], 0, 1),
        (mast_var_ids["x_16"], 0, 1),
        (mast_var_ids["x_17"], 0, 1)
    ]

    @test presolve_original_master.form.lower_multiplicity == 1
    @test presolve_original_master.form.upper_multiplicity == 1

    for (varuid, lb, ub) in var_ids_lbs_ubs
        @test presolve_original_master.form.lbs[varuid] == lb
        @test presolve_original_master.form.ubs[varuid] == ub
    end

    mast_constr_ids = Dict{String, Int}(ClMP.getname(master, constr) => k for (k, constr) in enumerate(presolve_original_master.row_to_constr))
    constr_ids_rhs_sense = [
        (mast_constr_ids["c1"], 1.0, ClMP.Greater),
        (mast_constr_ids["c2"], 1.0, ClMP.Greater),
        (mast_constr_ids["c3"], 1.0, ClMP.Greater),
        (mast_constr_ids["c4"], 1.0, ClMP.Greater),
        (mast_constr_ids["c5"], 1.0, ClMP.Greater),
        (mast_constr_ids["c6"], 1.0, ClMP.Greater),
    ]

    for (construid, rhs, sense) in constr_ids_rhs_sense
        @test presolve_original_master.form.rhs[construid] == rhs
        @test presolve_original_master.form.sense[construid] == sense
    end

    restricted_coef_matrix = [
        (mast_constr_ids["c1"], mast_var_ids["x_12"], 1.0),
        (mast_constr_ids["c2"], mast_var_ids["x_13"], 1.0),
        (mast_constr_ids["c3"], mast_var_ids["x_14"], 1.0),
        (mast_constr_ids["c4"], mast_var_ids["x_15"], 1.0),
        (mast_constr_ids["c5"], mast_var_ids["x_16"], 1.0),
        (mast_constr_ids["c6"], mast_var_ids["x_17"], 1.0),
        (mast_constr_ids["c1"], mast_var_ids["x_11"], 0.0),
        (mast_constr_ids["c2"], mast_var_ids["x_11"], 0.0),
        (mast_constr_ids["c3"], mast_var_ids["x_11"], 0.0),
        (mast_constr_ids["c4"], mast_var_ids["x_11"], 0.0),
        (mast_constr_ids["c5"], mast_var_ids["x_11"], 0.0),
        (mast_constr_ids["c6"], mast_var_ids["x_11"], 0.0),
    ]

    for (c, v, val) in restricted_coef_matrix
        @test presolve_original_master.form.col_major_coef_matrix[c, v] == val
    end
end
register!(unit_tests, "presolve_reformulation", build_dw_presolve_reformulation_with_var_not_in_coeff_matrix)

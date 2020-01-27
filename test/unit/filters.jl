function filters_unit_tests()
    filters_tests()
end

function filters_tests()

    v_data = ClF.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        sense = ClF.Free, is_active = true, is_explicit = true
    )

    v = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.MasterRepPricingVar, 23, 10), "fake_var";
        var_data = v_data
    )

    v2_data = ClF.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        sense = ClF.Free, is_active = true, is_explicit = true
    )

    v2 = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.DwSpPricingVar, 23, 10), "fake_var";
        var_data = v2_data
    )

    v3_data = ClF.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        sense = ClF.Free, is_active = false, is_explicit = true
    )

    v3 = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.MasterRepPricingSetupVar, 23, 10), "fake_var";
        var_data = v3_data
    )

    v4_data = ClF.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
        sense = ClF.Free, is_active = true, is_explicit = false
    )

    v4 = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.MasterRepPricingSetupVar, 23, 10), "fake_var";
        var_data = v4_data
    )

    c1_data = ClF.ConstrData(
        ; rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
        inc_val = -12.0, is_active = true, is_explicit = true
    )

    c1 = ClF.Constraint(
        ClF.Id{ClF.Constraint}(ClF.MasterBranchOnOrigVarConstr, 23, 10), "fake_constr";
        constr_data = c1_data
    )

    c2_data = ClF.ConstrData(
        ; rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )
    c2 = ClF.Constraint(
        ClF.Id{ClF.Constraint}(ClF.MasterPureConstr, 23, 10), "fake_constr";
        constr_data = c2_data
    )
#==
    @test ClF._active_master_rep_orig_constr_(c1) == false
    @test ClF._active_master_rep_orig_constr_(c2) == false
    @test ClF._explicit_(v) == true
    @test ClF._explicit_(c2) == false
    @test ClF._active_(v) == true
    @test ClF._active_(c2) == false
    @test ClF._explicit_(v) == true
    @test ClF._explicit_(c2) == false
    @test ClF._active_(v) == true
    @test ClF._active_(c2) == false
    @test ClF._active_pricing_sp_var_(v) == false
    @test ClF._active_pricing_sp_var_(v2) == true
    @test ClF._active_pricing_mast_rep_sp_var_(v) == true
    @test ClF._active_pricing_mast_rep_sp_var_(v2) == false
    @test ClF._active_pricing_mast_rep_sp_var_(v) == true
    @test ClF._active_pricing_mast_rep_sp_var_(v2) == false
    @test ClF._rep_of_orig_var_(v3) == false
    @test ClF._rep_of_orig_var_(v2) == false
    @test ClF._rep_of_orig_var_(v) == true
    @test ClF._active_explicit_(v) == true
    @test ClF._active_explicit_(v3) == false
    @test ClF._active_explicit_(v4) == false
    @test ClF._active_explicit_(v) == true
    @test ClF._active_explicit_(v3) == false
    @test ClF._active_explicit_(v4) == false
==#
end

function filters_unit_tests()
    filters_tests()
end

function filters_tests()

    v_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = true, is_explicit = true
    )

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MasterRepPricingVar;
        var_data = v_data
    )

    v2_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = true, is_explicit = true
    )

    v2 = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.DwSpPricingVar;
        var_data = v2_data
    )

    v3_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = false, is_explicit = true
    )

    v3 = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MasterRepPricingSetupVar;
        var_data = v3_data
    )

    v4_data = CL.VarData(
        ; cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        sense = CL.Free, is_active = true, is_explicit = false
    )

    v4 = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MasterRepPricingSetupVar;
        var_data = v4_data
    )

    c1_data = CL.ConstrData(
        ; rhs = -13.0, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = true, is_explicit = true
    )

    c1 = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterBranchOnOrigVarConstr;
        constr_data = c1_data
    )

    c2_data = CL.ConstrData(
        ; rhs = -13.0, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )
    c2 = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterPureConstr;
        constr_data = c2_data
    )

    @test CL._active_master_rep_orig_constr_(c1) == false
    @test CL._active_master_rep_orig_constr_(c2) == false
    @test CL._explicit_(v) == true
    @test CL._explicit_(c2) == false
    @test CL._active_(v) == true
    @test CL._active_(c2) == false
    @test CL._explicit_(v) == true
    @test CL._explicit_(c2) == false
    @test CL._active_(v) == true
    @test CL._active_(c2) == false
    @test CL._active_pricing_sp_var_(v) == false
    @test CL._active_pricing_sp_var_(v2) == true
    @test CL._active_pricing_mast_rep_sp_var_(v) == true
    @test CL._active_pricing_mast_rep_sp_var_(v2) == false
    @test CL._active_pricing_mast_rep_sp_var_(v) == true
    @test CL._active_pricing_mast_rep_sp_var_(v2) == false
    @test CL._rep_of_orig_var_(v3) == false
    @test CL._rep_of_orig_var_(v2) == false
    @test CL._rep_of_orig_var_(v) == true
    @test CL._active_explicit_(v) == true
    @test CL._active_explicit_(v3) == false
    @test CL._active_explicit_(v4) == false
    @test CL._active_explicit_(v) == true
    @test CL._active_explicit_(v3) == false
    @test CL._active_explicit_(v4) == false

end

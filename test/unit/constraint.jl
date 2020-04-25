function constraint_unit_tests()
    moi_constr_record_getters_and_setters_tests()
    constraint_getters_and_setters_tests()
end

function moi_constr_record_getters_and_setters_tests()
    c_rec = ClF.MoiConstrRecord(
        ; index = ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-15)
    )
    @test ClF.getindex(c_rec) == ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-15)

    ClF.setindex!(c_rec, ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-20))
    @test ClF.getindex(c_rec) == ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-20)
end

function constraint_getters_and_setters_tests()
    
    form = createformulation()
    
    c = ClF.setconstr!(form, "fake_constr", ClF.MasterBranchOnOrigVarConstr,
    rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
    inc_val = -12.0, is_active = false, is_explicit = false
    )
    
    ClF.setcurrhs!(form, c, 10.0)
    @test ClF.getcurrhs(form,c) == 10.0
    @test ClF.getperenerhs(form,c) == -13.0
    
    ClF.reset!(form, c)
    @test ClF.getcurrhs(form, c) == -13.0
    @test ClF.getperenerhs(form, c) == -13.0
end

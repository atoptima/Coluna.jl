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
    form = create_formulation!(Env(Coluna.Params()), Original())
    
    c = ClF.setconstr!(form, "fake_constr", ClF.MasterBranchOnOrigVarConstr,
        rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )
    
    @test ClF.getcurrhs(form, c) == -13.0
    ClF.setcurrhs!(form, c, 10.0)
    @test ClF.getcurrhs(form,c) == 10.0
    @test ClF.getperenrhs(form,c) == -13.0
    
    ClF.reset!(form, c)
    @test ClF.getcurrhs(form, c) == -13.0
    @test ClF.getperenrhs(form, c) == -13.0

    v = ClF.setvar!(form, "x", ClF.OriginalVar)

    c = ClF.setsinglevarconstr!(
        form, "fake_single_var_constr", getid(v), ClF.OriginalConstr; rhs = -2.0,
        kind = ClF.Essential, sense = ClF.Equal, inc_val = -12.0, is_active = true
    )

    cid = getid(c)

    @test ClF.getcurrhs(form,cid) == -2.0
    ClF.setcurrhs!(form, cid, -10.0)
    @test ClF.getcurrhs(form,cid) == -10.0
    @test ClF.getperenrhs(form,cid) == -2.0

    @test ClF.getcursense(form,cid) == ClF.Equal
    ClF.setcursense!(form, cid, ClF.Less)
    @test ClF.getcursense(form,cid) == ClF.Less
    @test ClF.getperensense(form,cid) == ClF.Equal

    @test ClF.getname(form,cid) == "fake_single_var_constr"
    return
end

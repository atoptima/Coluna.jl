function constraint_unit_tests()
    moi_constr_record_getters_and_setters_tests()
    constraint_getters_and_setters_tests()
end

function moi_constr_record_getters_and_setters_tests()
    c_rec = ClF.MoiConstrRecord(
        ; index = ClF.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-15)
    )
    @test ClF.getindex(c_rec) == ClF.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-15)

    ClF.setindex!(c_rec, ClF.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-20))
    @test ClF.getindex(c_rec) == ClF.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-20)
end

function constraint_getters_and_setters_tests()
    form = create_formulation!(Env(Coluna.Params()), Original())
    
    # Constraint

    c = ClF.setconstr!(form, "fake_constr", ClF.MasterBranchOnOrigVarConstr,
        rhs = -13.0, kind = ClF.Facultative, sense = ClF.Less,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    cid = getid(c)
    
    # rhs
    @test ClF.getcurrhs(form, cid) == -13.0
    ClF.setcurrhs!(form, cid, 10.0)
    @test ClF.getperenrhs(form, cid) == -13.0
    @test ClF.getcurrhs(form, cid) == 10.0

    ClF.setperenrhs!(form, cid, 45.0)
    @test ClF.getperenrhs(form, cid) == 45.0
    @test ClF.getcurrhs(form, cid) == 45.0
    ClF.setcurrhs!(form, cid, 12.0) # change cur before reset!

    # sense
    @test ClF.getcursense(form, cid) == ClF.Less
    ClF.setcursense!(form, cid, ClF.Greater)
    @test ClF.getperensense(form, cid) == ClF.Less
    @test ClF.getcursense(form, cid) == ClF.Greater

    ClF.setperensense!(form, cid, ClF.Equal)
    @test ClF.getperensense(form, cid) == ClF.Equal
    @test ClF.getcursense(form, cid) == ClF.Equal
    
    ClF.reset!(form, cid)
    @test ClF.getcurrhs(form, cid) == 45.0
    @test ClF.getperenrhs(form, cid) == 45.0

    # Single variable constraint

    v = ClF.setvar!(form, "x", ClF.OriginalVar)

    c = ClF.setsinglevarconstr!(
        form, "fake_single_var_constr", getid(v), ClF.OriginalConstr; rhs = -2.0,
        kind = ClF.Essential, sense = ClF.Equal, inc_val = -12.0, is_active = true
    )

    cid = getid(c)

    # rhs
    @test ClF.getcurrhs(form, cid) == -2.0
    ClF.setcurrhs!(form, cid, -10.0)
    @test ClF.getcurrhs(form, cid) == -10.0
    @test ClF.getperenrhs(form, cid) == -2.0

    ClF.setperenrhs!(form, cid, 33.0)
    @test ClF.getperenrhs(form, cid) == 33.0
    @test ClF.getcurrhs(form, cid) == 33.0

    # sense
    @test ClF.getcursense(form,cid) == ClF.Equal
    ClF.setcursense!(form, cid, ClF.Less)
    @test ClF.getcursense(form,cid) == ClF.Less
    @test ClF.getperensense(form,cid) == ClF.Equal

    ClF.setperensense!(form, cid, ClF.Greater)
    @test ClF.getperensense(form, cid) == ClF.Greater
    @test ClF.getcursense(form, cid) == ClF.Greater

    # explicit
    @test ClF.isexplicit(form, cid)
    @test ClF.isexplicit(form, c)

    # name
    @test ClF.getname(form,cid) == "fake_single_var_constr"
    return
end

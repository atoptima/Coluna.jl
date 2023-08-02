function getters_and_setters()
    form =  ClMP.create_formulation!(Coluna.Env{ClMP.VarId}(Coluna.Params()), ClMP.Original())
    constr = ClMP.setconstr!(form, "fake_constr", ClMP.MasterBranchOnOrigVarConstr,
        rhs = -13.0, kind = ClMP.Facultative, sense = ClMP.Less,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    cid = ClMP.getid(constr)

    # rhs
    @test ClMP.getcurrhs(form, cid) == -13.0
    ClMP.setcurrhs!(form, cid, 10.0)
    @test ClMP.getperenrhs(form, cid) == -13.0
    @test ClMP.getcurrhs(form, cid) == 10.0

    ClMP.setperenrhs!(form, cid, 45.0)
    @test ClMP.getperenrhs(form, cid) == 45.0
    @test ClMP.getcurrhs(form, cid) == 45.0
    ClMP.setcurrhs!(form, cid, 12.0) # change cur before reset!

    # sense
    @test ClMP.getcursense(form, cid) == ClMP.Less
    ClMP.setcursense!(form, cid, ClMP.Greater)
    @test ClMP.getperensense(form, cid) == ClMP.Less
    @test ClMP.getcursense(form, cid) == ClMP.Greater

    ClMP.setperensense!(form, cid, ClMP.Equal)
    @test ClMP.getperensense(form, cid) == ClMP.Equal
    @test ClMP.getcursense(form, cid) == ClMP.Equal
    
    ClMP.reset!(form, cid)
    @test ClMP.getcurrhs(form, cid) == 45.0
    @test ClMP.getperenrhs(form, cid) == 45.0
end
register!(unit_tests, "constraints", getters_and_setters)

function records()
    c_rec = ClMP.MoiConstrRecord(
        ; index = ClMP.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-15)
    )
    @test ClMP.getmoiindex(c_rec) == ClMP.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-15)

    ClMP.setmoiindex!(c_rec, ClMP.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-20))
    @test ClMP.getmoiindex(c_rec) == ClMP.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}(-20)
end
register!(unit_tests, "constraints", records)
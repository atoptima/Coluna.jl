function constraint_unit_tests()
    constr_data_getters_and_setters_tests()
    moi_constr_record_getters_and_setters_tests()
    constraint_getters_and_setters_tests()
end

function constr_data_getters_and_setters_tests()

    c_data = ClF.ConstrData(
        ; rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    @test ClF.getrhs(c_data) == -13.0
    @test ClF.is_active(c_data) == false
    @test ClF.is_explicit(c_data) == false
    @test ClF.getincval(c_data) == -12.0
    @test ClF.getsense(c_data) == ClF.Equal
    @test ClF.getkind(c_data) == ClF.Facultative

    ClF.setrhs!(c_data, 90.0)
    ClF.setkind!(c_data, ClF.MathProg.Core)
    ClF.setsense!(c_data, ClF.Less)
    ClF.setincval!(c_data, 90.0)
    ClF.set_is_active!(c_data, true)
    ClF.set_is_explicit!(c_data, true)

    @test ClF.getrhs(c_data) == 90.0
    @test ClF.getkind(c_data) == ClF.MathProg.Core
    @test ClF.getsense(c_data) == ClF.Less
    @test ClF.getincval(c_data) == 90.0
    @test ClF.is_active(c_data) == true
    @test ClF.is_explicit(c_data) == true

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

    c_data = ClF.ConstrData(
        ; rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    c = ClF.Constraint(
        ClF.Id{ClF.Constraint}(23, 10), "fake_constr", ClF.MasterBranchOnOrigVarConstr;
        constr_data = c_data
    )

    ClF.setcurrhs!(c, 10)
    @test ClF.getcurrhs(c) == 10
    @test ClF.getperenerhs(c) == -13

    ClF.reset!(c)
    @test ClF.getcurrhs(c) == -13
    @test ClF.getperenerhs(c) == -13
end

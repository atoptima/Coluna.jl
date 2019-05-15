function constraint_unit_tests()
    constr_data_getters_and_setters_tests()
    moi_constr_record_getters_and_setters_tests()
    constraint_getters_and_setters_tests()
end

function constr_data_getters_and_setters_tests()

    c_data = CL.ConstrData(
        ; rhs = -13.0, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    @test CL.getrhs(c_data) == -13.0
    @test CL.is_active(c_data) == false
    @test CL.is_explicit(c_data) == false
    @test CL.getincval(c_data) == -12.0
    @test CL.getsense(c_data) == CL.Equal
    @test CL.getkind(c_data) == CL.Facultative

    CL.setrhs!(c_data, 90.0)
    CL.setkind!(c_data, CL.Core)
    CL.setsense!(c_data, CL.Less)
    CL.setincval!(c_data, 90.0)
    CL.set_is_active!(c_data, true)
    CL.set_is_explicit!(c_data, true)

    @test CL.getrhs(c_data) == 90.0
    @test CL.getkind(c_data) == CL.Core
    @test CL.getsense(c_data) == CL.Less
    @test CL.getincval(c_data) == 90.0
    @test CL.is_active(c_data) == true
    @test CL.is_explicit(c_data) == true

end

function moi_constr_record_getters_and_setters_tests()
    c_rec = CL.MoiConstrRecord(
        ; index = CL.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-15)
    )
    @test CL.getindex(c_rec) == CL.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-15)

    CL.setindex!(c_rec, CL.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-20))
    @test CL.getindex(c_rec) == CL.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}(-20)
end

function constraint_getters_and_setters_tests()

    c_data = CL.ConstrData(
        ; rhs = -13.0, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    c = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterBranchConstr;
        constr_data = c_data
    )

    CL.setcurrhs!(c, 10)
    @test CL.getcurrhs(c) == 10
    @test CL.getperenerhs(c) == -13

    CL.reset!(c)
    @test CL.getcurrhs(c) == -13
    @test CL.getperenerhs(c) == -13
end

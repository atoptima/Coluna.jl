function varconstr_unit_tests()
    abstract_vc_data_getters_and_setters_tests()
    abstract_var_constr_getters_tests()
    varcosntr_helpers_tests()
end

function abstract_vc_data_getters_and_setters_tests()

    v_data = CL.VarData(
        ;cost = 13.0, lb = -10.0, ub = 100.0, kind = CL.Continuous,
        inc_val = -135.7, sense = CL.Free, is_active = false, is_explicit = false
    )

    @test CL.is_active(v_data) == false
    @test CL.is_explicit(v_data) == false
    @test CL.get_kind(v_data) == CL.Continuous
    @test CL.get_sense(v_data) == CL.Free
    @test CL.get_inc_val(v_data) == -135.7

    CL.set_inc_val!(v_data, 1.0)
    CL.set_is_active!(v_data, true)
    CL.set_is_explicit!(v_data, true)
    CL.set_kind!(v_data, CL.Integ)
    CL.set_sense!(v_data, CL.Negative)

    @test CL.is_active(v_data) == true
    @test CL.is_explicit(v_data) == true
    @test CL.get_kind(v_data) == CL.Integ
    @test CL.get_sense(v_data) == CL.Negative
    @test CL.get_inc_val(v_data) == 1.0


    c_data = CL.ConstrData(
        ; rhs = -13.0, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    @test CL.is_active(c_data) == false
    @test CL.is_explicit(c_data) == false
    @test CL.get_kind(c_data) == CL.Facultative
    @test CL.get_sense(c_data) == CL.Equal
    @test CL.get_inc_val(c_data) == -12.0

    CL.set_inc_val!(c_data, 1.0)
    CL.set_is_active!(c_data, true)
    CL.set_is_explicit!(c_data, true)
    CL.set_kind!(c_data, CL.Core)
    CL.set_sense!(c_data, CL.Less)

    @test CL.is_active(c_data) == true
    @test CL.is_explicit(c_data) == true
    @test CL.get_kind(c_data) == CL.Core
    @test CL.get_sense(c_data) == CL.Less
    @test CL.get_inc_val(c_data) == 1.0

end

function abstract_var_constr_getters_tests()

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MastRepBendSpVar
    )

    @test CL.get_id(v) == CL.Id{CL.Variable}(23, 10)
    @test CL.get_name(v) == "fake_var"
    @test CL.get_duty(v) == CL.MastRepBendSpVar
    @test CL.get_initial_data(v) === v.initial_data
    @test CL.get_cur_data(v) === v.cur_data
    @test CL.get_moi_record(v) === v.moi_record


    c = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterBranchConstr
    )

    @test CL.get_id(c) == CL.Id{CL.Constraint}(23, 10)
    @test CL.get_name(c) == "fake_constr"
    @test CL.get_duty(c) == CL.MasterBranchConstr
    @test CL.get_initial_data(c) === c.initial_data
    @test CL.get_cur_data(c) === c.cur_data
    @test CL.get_moi_record(c) === c.moi_record
end

function varcosntr_helpers_tests()

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MastRepBendSpVar
    )

    @test CL.get_uid(v) == 23
    @test CL.get_form(v) == 10

    @test CL.get_cur_kind(v) == CL.get_init_kind(v) == CL.Continuous
    @test CL.get_cur_sense(v) == CL.get_init_sense(v) == CL.Positive
    @test CL.get_cur_inc_val(v) == CL.get_init_inc_val(v) == -1.0
    @test CL.get_cur_is_active(v) == CL.get_init_is_active(v) == true
    @test CL.get_cur_is_explicit(v) == CL.get_init_is_explicit(v) == true

    CL.set_cur_kind(v, CL.Integ)
    CL.set_cur_sense(v, CL.Negative)
    CL.set_cur_inc_val(v, 10.0)
    CL.set_cur_is_active(v, false)
    CL.set_cur_is_explicit(v, false)

    @test CL.get_cur_kind(v) == CL.Integ
    @test CL.get_cur_sense(v) == CL.Negative
    @test CL.get_cur_inc_val(v) == 10.0
    @test CL.get_cur_is_active(v) == false
    @test CL.get_cur_is_explicit(v) == false

    c = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterBranchConstr
    )

    @test CL.get_uid(c) == 23
    @test CL.get_form(c) == 10

    @test CL.get_cur_kind(c) == CL.get_init_kind(c) == CL.Core
    @test CL.get_cur_sense(c) == CL.get_init_sense(c) == CL.Greater
    @test CL.get_cur_inc_val(c) == CL.get_init_inc_val(c) == -1.0
    @test CL.get_cur_is_active(c) == CL.get_init_is_active(c) == true
    @test CL.get_cur_is_explicit(c) == CL.get_init_is_explicit(c) == true

    CL.set_cur_kind(c, CL.Facultative)
    CL.set_cur_sense(c, CL.Less)
    CL.set_cur_inc_val(c, 10.0)
    CL.set_cur_is_active(c, false)
    CL.set_cur_is_explicit(c, false)

    @test CL.get_cur_kind(c) == CL.Facultative
    @test CL.get_cur_sense(c) == CL.Less
    @test CL.get_cur_inc_val(c) == 10.0
    @test CL.get_cur_is_active(c) == false
    @test CL.get_cur_is_explicit(c) == false

end

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
    @test CL.getkind(v_data) == CL.Continuous
    @test CL.getsense(v_data) == CL.Free
    @test CL.getincval(v_data) == -135.7

    CL.setincval!(v_data, 1.0)
    CL.set_is_active!(v_data, true)
    CL.set_is_explicit!(v_data, true)
    CL.setkind!(v_data, CL.Integ)
    CL.setsense!(v_data, CL.Negative)

    @test CL.is_active(v_data) == true
    @test CL.is_explicit(v_data) == true
    @test CL.getkind(v_data) == CL.Integ
    @test CL.getsense(v_data) == CL.Negative
    @test CL.getincval(v_data) == 1.0


    c_data = CL.ConstrData(
        ; rhs = -13.0, kind = CL.Facultative, sense = CL.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    @test CL.is_active(c_data) == false
    @test CL.is_explicit(c_data) == false
    @test CL.getkind(c_data) == CL.Facultative
    @test CL.getsense(c_data) == CL.Equal
    @test CL.getincval(c_data) == -12.0

    CL.setincval!(c_data, 1.0)
    CL.set_is_active!(c_data, true)
    CL.set_is_explicit!(c_data, true)
    CL.setkind!(c_data, CL.Core)
    CL.setsense!(c_data, CL.Less)

    @test CL.is_active(c_data) == true
    @test CL.is_explicit(c_data) == true
    @test CL.getkind(c_data) == CL.Core
    @test CL.getsense(c_data) == CL.Less
    @test CL.getincval(c_data) == 1.0

end

function abstract_var_constr_getters_tests()

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MasterPureVar
    )

    @test CL.getid(v) == CL.Id{CL.Variable}(23, 10)
    @test CL.getname(v) == "fake_var"
    @test CL.getduty(v) == CL.MasterPureVar
    @test CL.getrecordeddata(v) === v.perene_data
    @test CL.getcurdata(v) === v.cur_data
    @test CL.getmoirecord(v) === v.moirecord


    c = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterBranchOnOrigVarConstr
    )

    @test CL.getid(c) == CL.Id{CL.Constraint}(23, 10)
    @test CL.getname(c) == "fake_constr"
    @test CL.getduty(c) == CL.MasterBranchOnOrigVarConstr
    @test CL.getrecordeddata(c) === c.perene_data
    @test CL.getcurdata(c) === c.cur_data
    @test CL.getmoirecord(c) === c.moirecord
end

function varcosntr_helpers_tests()

    v = CL.Variable(
        CL.Id{CL.Variable}(23, 10), "fake_var", CL.MasterPureVar
    )

    @test CL.getuid(v) == 23
    @test CL.getform(v) == 10

    @test CL.getcurkind(v) == CL.getperenekind(v) == CL.Continuous
    @test CL.getcursense(v) == CL.getperenesense(v) == CL.Positive
    @test CL.getcurincval(v) == CL.getpereneincval(v) == -1.0
    @test CL.get_cur_is_active(v) == CL.get_init_is_active(v) == true
    @test CL.get_cur_is_explicit(v) == CL.get_init_is_explicit(v) == true

    CL.setcurkind(v, CL.Integ)
    CL.setcursense(v, CL.Negative)
    CL.setcurincval(v, 10.0)
    CL.set_cur_is_active(v, false)
    CL.set_cur_is_explicit(v, false)

    @test CL.getcurkind(v) == CL.Integ
    @test CL.getcursense(v) == CL.Negative
    @test CL.getcurincval(v) == 10.0
    @test CL.get_cur_is_active(v) == false
    @test CL.get_cur_is_explicit(v) == false

    c = CL.Constraint(
        CL.Id{CL.Constraint}(23, 10), "fake_constr", CL.MasterBranchOnOrigVarConstr
    )

    @test CL.getuid(c) == 23
    @test CL.getform(c) == 10

    @test CL.getcurkind(c) == CL.getperenekind(c) == CL.Core
    @test CL.getcursense(c) == CL.getperenesense(c) == CL.Greater
    @test CL.getcurincval(c) == CL.getpereneincval(c) == -1.0
    @test CL.get_cur_is_active(c) == CL.get_init_is_active(c) == true
    @test CL.get_cur_is_explicit(c) == CL.get_init_is_explicit(c) == true

    CL.setcurkind(c, CL.Facultative)
    CL.setcursense(c, CL.Less)
    CL.setcurincval(c, 10.0)
    CL.set_cur_is_active(c, false)
    CL.set_cur_is_explicit(c, false)

    @test CL.getcurkind(c) == CL.Facultative
    @test CL.getcursense(c) == CL.Less
    @test CL.getcurincval(c) == 10.0
    @test CL.get_cur_is_active(c) == false
    @test CL.get_cur_is_explicit(c) == false

end

function varconstr_unit_tests()
    abstract_vc_data_getters_and_setters_tests()
    abstract_var_constr_getters_tests()
    varcosntr_helpers_tests()
end

function abstract_vc_data_getters_and_setters_tests()

    v_data = ClFF.VarData(
        ;cost = 13.0, lb = -10.0, ub = 100.0, kind = ClFF.Continuous,
        inc_val = -135.7, sense = ClFF.Free, is_active = false, is_explicit = false
    )

    @test ClFF.is_active(v_data) == false
    @test ClFF.is_explicit(v_data) == false
    @test ClFF.getkind(v_data) == ClFF.Continuous
    @test ClFF.getsense(v_data) == ClFF.Free
    @test ClFF.getincval(v_data) == -135.7

    ClFF.setincval!(v_data, 1.0)
    ClFF.set_is_active!(v_data, true)
    ClFF.set_is_explicit!(v_data, true)
    ClFF.setkind!(v_data, ClFF.Integ)
    ClFF.setsense!(v_data, ClFF.Negative)

    @test ClFF.is_active(v_data) == true
    @test ClFF.is_explicit(v_data) == true
    @test ClFF.getkind(v_data) == ClFF.Integ
    @test ClFF.getsense(v_data) == ClFF.Negative
    @test ClFF.getincval(v_data) == 1.0


    c_data = ClFF.ConstrData(
        ; rhs = -13.0, kind = ClFF.Facultative, sense = ClFF.Equal,
        inc_val = -12.0, is_active = false, is_explicit = false
    )

    @test ClFF.is_active(c_data) == false
    @test ClFF.is_explicit(c_data) == false
    @test ClFF.getkind(c_data) == ClFF.Facultative
    @test ClFF.getsense(c_data) == ClFF.Equal
    @test ClFF.getincval(c_data) == -12.0

    ClFF.setincval!(c_data, 1.0)
    ClFF.set_is_active!(c_data, true)
    ClFF.set_is_explicit!(c_data, true)
    ClFF.setkind!(c_data, ClFF.Formulations.Core)
    ClFF.setsense!(c_data, ClFF.Less)

    @test ClFF.is_active(c_data) == true
    @test ClFF.is_explicit(c_data) == true
    @test ClFF.getkind(c_data) == ClFF.Formulations.Core
    @test ClFF.getsense(c_data) == ClFF.Less
    @test ClFF.getincval(c_data) == 1.0

end

function abstract_var_constr_getters_tests()

    v = ClFF.Variable(
        ClFF.Id{ClFF.Variable}(23, 10), "fake_var", ClFF.MasterPureVar
    )

    @test ClFF.getid(v) == ClFF.Id{ClFF.Variable}(23, 10)
    @test ClFF.getname(v) == "fake_var"
    @test ClFF.getduty(v) == ClFF.MasterPureVar
    @test ClFF.getrecordeddata(v) === v.perene_data
    @test ClFF.getcurdata(v) === v.cur_data
    @test ClFF.getmoirecord(v) === v.moirecord


    c = ClFF.Constraint(
        ClFF.Id{ClFF.Constraint}(23, 10), "fake_constr", ClFF.MasterBranchOnOrigVarConstr
    )

    @test ClFF.getid(c) == ClFF.Id{ClFF.Constraint}(23, 10)
    @test ClFF.getname(c) == "fake_constr"
    @test ClFF.getduty(c) == ClFF.MasterBranchOnOrigVarConstr
    @test ClFF.getrecordeddata(c) === c.perene_data
    @test ClFF.getcurdata(c) === c.cur_data
    @test ClFF.getmoirecord(c) === c.moirecord
end

function varcosntr_helpers_tests()

    v = ClFF.Variable(
        ClFF.Id{ClFF.Variable}(23, 10), "fake_var", ClFF.MasterPureVar
    )

    @test ClF.getuid(v) == 23
    @test ClF.getoriginformuid(v) == 10

    @test ClF.getcurkind(v) == ClF.getperenekind(v) == ClF.Continuous
    @test ClF.getcursense(v) == ClF.getperenesense(v) == ClF.Positive
    @test ClF.getcurincval(v) == ClF.getpereneincval(v) == -1.0
    @test ClF.get_cur_is_active(v) == ClF.get_init_is_active(v) == true
    @test ClF.get_cur_is_explicit(v) == ClF.get_init_is_explicit(v) == true

    ClF.setcurkind(v, ClF.Integ)
    ClF.setcursense(v, ClF.Negative)
    ClF.setcurincval(v, 10.0)
    ClF.set_cur_is_active(v, false)
    ClF.set_cur_is_explicit(v, false)

    @test ClF.getcurkind(v) == ClF.Integ
    @test ClF.getcursense(v) == ClF.Negative
    @test ClF.getcurincval(v) == 10.0
    @test ClF.get_cur_is_active(v) == false
    @test ClF.get_cur_is_explicit(v) == false

    c = ClF.Constraint(
        ClF.Id{ClF.Constraint}(23, 10), "fake_constr", ClF.MasterBranchOnOrigVarConstr
    )

    @test ClF.getuid(c) == 23
    @test ClF.getoriginformuid(c) == 10

    @test ClF.getcurkind(c) == ClF.getperenekind(c) == ClF.Core
    @test ClF.getcursense(c) == ClF.getperenesense(c) == ClF.Greater
    @test ClF.getcurincval(c) == ClF.getpereneincval(c) == -1.0
    @test ClF.get_cur_is_active(c) == ClF.get_init_is_active(c) == true
    @test ClF.get_cur_is_explicit(c) == ClF.get_init_is_explicit(c) == true

    ClF.setcurkind(c, ClF.Facultative)
    ClF.setcursense(c, ClF.Less)
    ClF.setcurincval(c, 10.0)
    ClF.set_cur_is_active(c, false)
    ClF.set_cur_is_explicit(c, false)

    @test ClF.getcurkind(c) == ClF.Facultative
    @test ClF.getcursense(c) == ClF.Less
    @test ClF.getcurincval(c) == 10.0
    @test ClF.get_cur_is_active(c) == false
    @test ClF.get_cur_is_explicit(c) == false

end

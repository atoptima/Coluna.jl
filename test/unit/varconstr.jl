function varconstr_unit_tests()
    abstract_vc_data_getters_and_setters_tests()
    abstract_var_constr_getters_tests()
    varcosntr_helpers_tests()
end

function abstract_vc_data_getters_and_setters_tests()

    # v_data = ClF.VarData(
    #     ;cost = 13.0, lb = -10.0, ub = 100.0, kind = ClF.Continuous,
    #     inc_val = -135.7, sense = ClF.Free, is_active = false, is_explicit = false
    # )

    # @test ClF.is_active(v_data) == false
    # @test ClF.is_explicit(v_data) == false
    # @test ClF.getkind(v_data) == ClF.Continuous
    # @test ClF.getsense(v_data) == ClF.Free
    # @test ClF.getincval(v_data) == -135.7

    # #ClF.setincval!(v_data, 1.0)
    # ClF.set_is_active!(v_data, true)
    # ClF.set_is_explicit!(v_data, true)
    # ClF.setkind!(v_data, ClF.Integ)
    # ClF.setsense!(v_data, ClF.Negative)

    # @test ClF.is_active(v_data) == true
    # @test ClF.is_explicit(v_data) == true
    # @test ClF.getkind(v_data) == ClF.Integ
    # @test ClF.getsense(v_data) == ClF.Negative
    # @test ClF.getincval(v_data) == 1.0


    # c_data = ClF.ConstrData(
    #     ; rhs = -13.0, kind = ClF.Facultative, sense = ClF.Equal,
    #     inc_val = -12.0, is_active = false, is_explicit = false
    # )

    # @test ClF.is_active(c_data) == false
    # @test ClF.is_explicit(c_data) == false
    # @test ClF.getkind(c_data) == ClF.Facultative
    # @test ClF.getsense(c_data) == ClF.Equal
    # @test ClF.getincval(c_data) == -12.0

    # #ClF.setincval!(c_data, 1.0)
    # ClF.set_is_active!(c_data, true)
    # ClF.set_is_explicit!(c_data, true)
    # ClF.setkind!(c_data, ClF.MathProg.Core)
    # ClF.setsense!(c_data, ClF.Less)

    # @test ClF.is_active(c_data) == true
    # @test ClF.is_explicit(c_data) == true
    # @test ClF.getkind(c_data) == ClF.MathProg.Core
    # @test ClF.getsense(c_data) == ClF.Less
    # @test ClF.getincval(c_data) == 1.0

end

function abstract_var_constr_getters_tests()

    v = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.MasterPureVar, 23, 10), "fake_var"
    )
    vid = ClF.getid(v)
    @test vid == ClF.Id{ClF.Variable}(ClF.MasterPureVar, 23, 10)
    @test ClF.getname(v) == "fake_var"
    #@test vid == ClF.MasterPureVar
    #@test ClF.getrecordeddata(v) === v.perene_data
    #@test ClF.getcurdata(v) === v.cur_data
    @test ClF.getmoirecord(v) === v.moirecord


    c = ClF.Constraint(
        ClF.Id{ClF.Constraint}(ClF.MasterBranchOnOrigVarConstr, 23, 10), "fake_constr"
    )
    cid = ClF.getid(c) 
    @test cid == ClF.Id{ClF.Constraint}(ClF.MasterBranchOnOrigVarConstr, 23, 10)
    @test ClF.getname(c) == "fake_constr"
    #@test getduty(cid) == ClF.MasterBranchOnOrigVarConstr
    #@test ClF.getrecordeddata(c) === c.perene_data
    #@test ClF.getcurdata(c) === c.cur_data
    @test ClF.getmoirecord(c) === c.moirecord
end

function varcosntr_helpers_tests()

    v = ClF.Variable(
        ClF.Id{ClF.Variable}(ClF.MasterPureVar, 23, 10), "fake_var"
    )
    form = createformulation()
 
    ClF._addvar!(form, v)

    @test ClF.getuid(v) == 23
    @test ClF.getoriginformuid(v) == 10

   @test ClF.getcurkind(form, v) == ClF.getperenekind(form, v) == ClF.Continuous
   @test ClF.getcursense(form, v) == ClF.getperenesense(form, v) == ClF.Positive
   @test ClF.getcurincval(form, v) == ClF.getpereneincval(form, v) == -1.0
   @test ClF.getcurisactive(form, v) == ClF.getpereneisactive(form, v) == true
   @test ClF.getcurisexplicit(form, v) == ClF.getpereneisexplicit(form, v) == true

    ClF.setcurkind!(form, v, ClF.Integ)
    ClF.setcursense!(form, v, ClF.Negative)
    ClF.setcurincval!(form, v, 10.0)
    ClF.setcurisactive!(form, v, false)
    ClF.setcurisexplicit!(form, v, false)

    @test ClF.getcurkind(form, v) == ClF.Integ
    @test ClF.getcursense(form, v) == ClF.Negative
    @test ClF.getcurincval(form, v) == 10.0
    @test ClF.getcurisactive(form, v) == false
    @test ClF.getcurisexplicit(form, v) == false

    c = ClF.Constraint(
        ClF.Id{ClF.Constraint}(ClF.MasterBranchOnOrigVarConstr, 23, 10), "fake_constr"
    )
    ClF._addconstr!(form, c)

    @test ClF.getuid(c) == 23
    @test ClF.getoriginformuid(c) == 10

    @test ClF.getcurkind(form, c) == ClF.getperenekind(form, c) == ClF.Core
    @test ClF.getcursense(form, c) == ClF.getperenesense(form, c) == ClF.Greater
    @test ClF.getcurincval(form, c) == ClF.getpereneincval(form, c) == -1.0
    @test ClF.getcurisactive(form, c) == ClF.getpereneisactive(form, c) == true
    @test ClF.getcurisexplicit(form, c) == ClF.getpereneisexplicit(form, c) == true

    ClF.setcurkind!(form, c, ClF.Facultative)
    ClF.setcursense!(form, c, ClF.Less)
    ClF.setcurincval!(form, c, 10.0)
    ClF.setcurisactive!(form, c, false)
    ClF.setcurisexplicit!(form, c, false)

    @test ClF.getcurkind(form, c) == ClF.Facultative
    @test ClF.getcursense(form, c) == ClF.Less
    @test ClF.getcurincval(form, c) == 10.0
    @test ClF.getcurisactive(form, c) == false
    @test ClF.getcurisexplicit(form, c) == false

end

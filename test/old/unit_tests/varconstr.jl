function varconstr_unit_tests()

    vc_counter_test()
    varconstr_test()
    variable_test()
    constraint_test()
    find_first_test()

end

function vc_counter_test()
    vc_counter = CL.VarConstrCounter(0)
    new_vc_value = CL.increment_counter(vc_counter)
    @test vc_counter.value == 1
    @test new_vc_value == 1
end

function varconstr_test()
    vc_counter = CL.VarConstrCounter(0)
    vc_1 = CL.VarConstr(vc_counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0)
    @test vc_1.vc_ref == vc_counter.value == 1
    @test vc_1.name == "vc_1"
    @test vc_1.in_cur_prob == false
    @test vc_1.in_cur_form == false
    @test vc_1.directive == 'U'
    @test vc_1.priority == 2.0
    @test vc_1.cost_rhs == 1.0
    @test vc_1.sense == 'P'
    @test vc_1.vc_type == 'C'
    @test vc_1.flag == 's'

    vc_2 = CL.VarConstr(vc_1, vc_counter)
    @test vc_2.vc_ref == vc_counter.value == 2
    @test vc_2.name == ""
    @test vc_2.in_cur_prob == vc_1.in_cur_prob == false
    @test vc_2.in_cur_form == vc_1.in_cur_form == false
    @test vc_2.directive == vc_1.directive == 'U'
    @test vc_2.priority == vc_1.priority == 2.0
    @test vc_2.cost_rhs == vc_1.cost_rhs == 1.0
    @test vc_2.sense == vc_1.sense == 'P'
    @test vc_2.vc_type == vc_1.vc_type == 'C'
    @test vc_2.flag == vc_1.flag == 's'
end

function variable_test()
    vc_counter = CL.VarConstrCounter(0)
    var_1 = CL.Variable(vc_counter, "var_1", 1.0, 'P', 'B', 's', 'U', 2.0, 0.0, 1.0)
    @test var_1.vc_ref == vc_counter.value == 1
    @test var_1.name == "var_1"
    @test var_1.in_cur_prob == false
    @test var_1.in_cur_form == false
    @test var_1.directive == 'U'
    @test var_1.priority == 2.0
    @test var_1.cost_rhs == 1.0
    @test var_1.sense == 'P'
    @test var_1.vc_type == 'B'
    @test var_1.flag == 's'
    @test var_1.lower_bound == 0.0
    @test var_1.upper_bound == 1.0

    var_2 = CL.Variable(var_1, vc_counter)
    @test var_2.vc_ref == vc_counter.value == 2
    @test var_2.name == ""
    @test var_2.in_cur_prob == var_1.in_cur_prob == false
    @test var_2.in_cur_form == var_1.in_cur_form == false
    @test var_2.directive == var_1.directive == 'U'
    @test var_2.priority == var_1.priority == 2.0
    @test var_2.cost_rhs == var_1.cost_rhs == 1.0
    @test var_2.sense == var_1.sense == 'P'
    @test var_2.vc_type == var_1.vc_type == 'B'
    @test var_2.flag == var_1.flag == 's'
    @test var_2.lower_bound == -Inf
    @test var_2.upper_bound == Inf
end

function constraint_test()
    vc_counter = CL.VarConstrCounter(0)
    constr_1 = CL.Constraint(vc_counter, "C_1", 5.0, 'L', 'M', 's')
    @test constr_1.vc_ref == vc_counter.value == 1
    @test constr_1.name == "C_1"
    @test constr_1.in_cur_prob == false
    @test constr_1.in_cur_form == false
    @test constr_1.directive == 'U'
    @test constr_1.priority == 1.0
    @test constr_1.cost_rhs == 5.0
    @test constr_1.sense == 'L'
    @test constr_1.vc_type == 'M'
    @test constr_1.flag == 's'
end

function find_first_test()
    vc_counter = CL.VarConstrCounter(0)
    vc_1 = CL.VarConstr(vc_counter, "vc_1", 1.0, 'P', 'C', 's', 'U', 2.0)
    vc_2 = CL.VarConstr(vc_1, vc_counter)
    vc_3 = CL.VarConstr(vc_1, vc_counter)
    vc_4 = CL.VarConstr(vc_1, vc_counter)
    vc_5 = CL.VarConstr(vc_1, vc_counter)

    vec = [vc_2, vc_5, vc_1, vc_1, vc_3, vc_4, vc_5]
    @test CL.find_first(vec, 5) == 2
    @test CL.find_first(vec, 6) == 0
end


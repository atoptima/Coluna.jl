function row_activity()
    coef_matrix = sparse([
        0  0 -1    1  0  1  2.5 # <= 4
        0  0  1   -1  0 -1 -2.5 # >= -4
        1  0  0    0  1  0   0   # == 1
        0  1  2   -4  0  0   0   # >= 2
        0  1  2   -4  0  0   0   # <= 1
        1 -2  3  5.5  0  1   1   # == 6
    ])

    rhs = [4, -4, 1, 2, 1, 6]
    sense = [Less, Greater, Equal, Greater, Less, Equal]
    lbs = [1,   0,  2, 1, -1, -Inf, 0]
    ubs = [10, Inf, 3, 2,  1,   0,  1]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs)

    @test Coluna.Algorithm.row_min_activity(form, 1) == transpose(coef_matrix[1,:]) * [0, 0, ubs[3], lbs[4], 0, lbs[6], lbs[7]] # ok
    @test Coluna.Algorithm.row_max_activity(form, 1) == transpose(coef_matrix[1,:]) * [0, 0, lbs[3], ubs[4], 0, ubs[6], ubs[7]] # ok
    @test Coluna.Algorithm.row_min_activity(form, 2) == transpose(coef_matrix[2,:]) * [0, 0, lbs[3], ubs[4], 0, ubs[6], ubs[7]] # ok
    @test Coluna.Algorithm.row_max_activity(form, 2) == transpose(coef_matrix[2,:]) * [0, 0, ubs[3], lbs[4], 0, lbs[6], lbs[7]] # ok
    @test Coluna.Algorithm.row_min_activity(form, 3) == transpose(coef_matrix[3,:]) * [lbs[1], 0, 0, 0, lbs[5], 0, 0] # ok
    @test Coluna.Algorithm.row_max_activity(form, 3) == transpose(coef_matrix[3,:]) * [ubs[1], 0, 0, 0, ubs[5], 0, 0] # ok
    @test Coluna.Algorithm.row_min_activity(form, 4) == transpose(coef_matrix[4,:]) * [0, lbs[2], lbs[3], ubs[4], 0, 0, 0] # ok
    @test Coluna.Algorithm.row_max_activity(form, 4) == transpose(coef_matrix[4,:]) * [0, ubs[2], ubs[3], lbs[4], 0, 0, 0] # ok
    @test Coluna.Algorithm.row_min_activity(form, 5) == transpose(coef_matrix[5,:]) * [0, lbs[2], lbs[3], ubs[4], 0, 0, 0] # ok
    @test Coluna.Algorithm.row_max_activity(form, 5) == transpose(coef_matrix[5,:]) * [0, ubs[2], ubs[3], lbs[4], 0, 0, 0] # ok
    @test Coluna.Algorithm.row_min_activity(form, 6) == transpose(coef_matrix[6,:]) * [lbs[1], ubs[2], lbs[3], lbs[4], 0, lbs[6], lbs[7]] # ok
    @test Coluna.Algorithm.row_max_activity(form, 6) == transpose(coef_matrix[6,:]) * [ubs[1], lbs[2], ubs[3], ubs[4], 0, ubs[6], ubs[7]] # ok
end
register!(unit_tests, "presolve_helper", row_activity)

function row_slack()
    coef_matrix = sparse([
        0  0 -1    1  0  1  2.5 # <= 4
        0  0  1   -1  0 -1 -2.5 # >= -4
        1  0  0    0  1  0   0   # == 1
        0  1  2   -4  0  0   0   # >= 2
        0  1  2   -4  0  0   0   # <= 1
        1 -2  3  5.5  0  1   1   # == 6
    ])

    rhs = [4, -4, 1, 2, 1, 6]
    sense = [Less, Greater, Equal, Greater, Less, Equal]
    lbs = [1,   0,  2, 1, -1, -Inf, 0]
    ubs = [10, Inf, 3, 2,  1,   0,  1]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs)

    @test Coluna.Algorithm.row_min_slack(form, 1) == rhs[1] - Coluna.Algorithm.row_max_activity(form, 1) # ok
    @test Coluna.Algorithm.row_max_slack(form, 1) == rhs[1] - Coluna.Algorithm.row_min_activity(form, 1) # ok
    @test Coluna.Algorithm.row_min_slack(form, 2) == rhs[2] - Coluna.Algorithm.row_max_activity(form, 2) # ok
    @test Coluna.Algorithm.row_max_slack(form, 2) == rhs[2] - Coluna.Algorithm.row_min_activity(form, 2) # ok
    @test Coluna.Algorithm.row_min_slack(form, 3) == rhs[3] - Coluna.Algorithm.row_max_activity(form, 3) # ok
    @test Coluna.Algorithm.row_max_slack(form, 3) == rhs[3] - Coluna.Algorithm.row_min_activity(form, 3) # ok
    @test Coluna.Algorithm.row_min_slack(form, 4) == rhs[4] - Coluna.Algorithm.row_max_activity(form, 4) # ok
    @test Coluna.Algorithm.row_max_slack(form, 4) == rhs[4] - Coluna.Algorithm.row_min_activity(form, 4) # ok
    @test Coluna.Algorithm.row_min_slack(form, 5) == rhs[5] - Coluna.Algorithm.row_max_activity(form, 5) # ok
    @test Coluna.Algorithm.row_max_slack(form, 5) == rhs[5] - Coluna.Algorithm.row_min_activity(form, 5) # ok
    @test Coluna.Algorithm.row_min_slack(form, 6) == rhs[6] - Coluna.Algorithm.row_max_activity(form, 6) # ok
    @test Coluna.Algorithm.row_max_slack(form, 6) == rhs[6] - Coluna.Algorithm.row_min_activity(form, 6) # ok
end
register!(unit_tests, "presolve_helper", row_slack)

function test_inner_unbounded_row()
    @test Coluna.Algorithm._unbounded_row(Less, Inf)
    @test Coluna.Algorithm._unbounded_row(Greater, -Inf)
    @test !Coluna.Algorithm._unbounded_row(Less, -Inf)
    @test !Coluna.Algorithm._unbounded_row(Greater, Inf)
    @test !Coluna.Algorithm._unbounded_row(Equal, Inf)
    @test !Coluna.Algorithm._unbounded_row(Equal, -Inf)
    @test !Coluna.Algorithm._unbounded_row(Less, 15)
    @test !Coluna.Algorithm._unbounded_row(Greater, 15)
end
register!(unit_tests, "presolve_helper", test_inner_unbounded_row)

function test_inner_row_bounded_by_var_bounds_1()
    # x + y + z >= 1
    coeffs = [1, 1, 1]
    lbs = [1, 1, 1]
    ubs = [10, 10, 10]
    rhs = 1
    sense = Greater

    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test !Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)

    # x + y + z >= 4
    rhs = 4
    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test !Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test !Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)

    # x + y + z >= 31
    rhs = 31
    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test !Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)
end
register!(unit_tests, "presolve_helper", test_inner_row_bounded_by_var_bounds_1)

function test_inner_row_bounded_by_var_bounds_2()
    # x + y + z <= 9
    coeffs = [1, 1, 1]
    lbs = [1, 1, 1]
    ubs = [3, 3, 3]
    rhs = 9
    sense = Less

    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test !Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)

    # x + y + z <= 4
    rhs = 4
    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test !Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test !Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)

    # x + y + z <= -1
    rhs = -1
    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test !Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)
end
register!(unit_tests, "presolve_helper", test_inner_row_bounded_by_var_bounds_2)

function test_inner_row_bounded_by_var_bounds_3()
    # x + y + z == 3
    coeffs = [1, 1, 1]
    lbs = [1, 1, 1]
    ubs = [1, 1, 1]
    rhs = 3
    sense = Equal

    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test !Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)

    # x + y + z == 4
    rhs = 4
    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @show min_slack, max_slack

    @test !Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)

    # x + y + z == 2
    lbs = [0, 0, 0]
    ubs = [1, 1, 1]
    rhs = 2

    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    @test !Coluna.Algorithm._row_bounded_by_var_bounds(sense, min_slack, max_slack, 1e-6)
    @test !Coluna.Algorithm._infeasible_row(sense, min_slack, max_slack, 1e-6)
end
register!(unit_tests, "presolve_helper", test_inner_row_bounded_by_var_bounds_3)

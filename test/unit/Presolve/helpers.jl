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
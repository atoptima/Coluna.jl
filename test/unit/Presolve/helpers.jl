function test_presolve_builder1()
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
    @test form.nb_vars == 7
    @test form.nb_constrs == 6
    @test all(form.coef_matrix .== coef_matrix)
    @test all(form.rhs .== rhs)
    @test all(form.sense .== sense)
    @test all(form.lbs .== lbs)
    @test all(form.ubs .== ubs)
    return
end
register!(unit_tests, "presolve_helper", test_presolve_builder1)

# Test rows deactivation.
function test_presolve_builder2()
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

    # Deactivate some rows.
    rows_to_deactivate = [1, 3, 6]
    vars_to_fix = Int[]
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}()

    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, vars_to_fix, tightened_bounds)
    @test form2.nb_vars == 7
    @test form2.nb_constrs == 3
    @test all(form2.coef_matrix .== coef_matrix[[2, 4, 5], :])
    @test all(form2.rhs .== rhs[[2, 4, 5]])
    @test all(form2.sense .== sense[[2, 4, 5]])
    @test all(form2.lbs .== lbs)
    @test all(form2.ubs .== ubs)
end
register!(unit_tests, "presolve_helper", test_presolve_builder2)

# Test vars fixing.
function test_presolve_builder3()
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
    lbs = [10, 2,  1, 1, -1,  0,  -1]
    ubs = [10, 3,  1, 2,  1,  0,  -1]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs)

    # Deactivate some rows.
    rows_to_deactivate = Int[]
    vars_to_fix = Int[1, 3, 6, 7]
    tightened_bounds = Dict{Int,Tuple{Float64, Bool, Float64, Bool}}()

    #      -1  - 2.5  # <= 4  ->  7.5
    #      1   + 2.5  # >= -4 -> -7.5
    # 10              # == 1  ->   -9
    #      2          # >= 2  ->    0
    #      2          # <= 1  ->   -1
    # 10+  3     -1   # == 6  ->   -6

    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, vars_to_fix, tightened_bounds)
    @test form2.nb_vars == 3
    @test form2.nb_constrs == 6
    @test all(form2.coef_matrix .== coef_matrix[:, [2, 4, 5]])
    @show form2.rhs
    @test all(form2.rhs .== [7.5, -7.5, -9, 0, -1, -6])
    @test all(form2.sense .== sense)
    @test all(form2.lbs .== lbs[[2, 4, 5]])
    @test all(form2.ubs .== ubs[[2, 4, 5]])
end
register!(unit_tests, "presolve_helper", test_presolve_builder3)

# Test bound tightening.
function test_presolve_builder4()
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

    rows_to_deactivate = Int[]
    vars_to_fix = Int[]
    tightened_bounds = Dict{Int,Tuple{Float64, Bool, Float64, Bool}}(
        1 => (1, false, 2, true),
        2 => (0, true, 1, true),
        3 => (-1, false, 3, false),
        6 => (0.5, true, 0.5, true) # the flag forces the update!
    )
    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, vars_to_fix, tightened_bounds)
    @test form2.nb_vars == 7
    @test form2.nb_constrs == 6
    @test all(form2.coef_matrix .== coef_matrix)
    @test all(form2.rhs .== rhs)
    @test all(form2.sense .== sense)
    @show form2.lbs
    @test all(form2.lbs .== [1, 0, 2, 1, -1, 0.5, 0])
    @show form2.ubs
    @test all(form2.ubs .== [2, 1, 3, 2, 1, 0.5, 1])
end
register!(unit_tests, "presolve_helper", test_presolve_builder4)

function test_presolve_builder5()

end
register!(unit_tests, "presolve_helper", test_presolve_builder5)

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

function test_var_bounds_from_row1()
    # x + 2y + 3z >= 10
    # 0 <= x <= 10
    # 0 <= y <= 2
    # 0 <= z <= 1
    # therefore x >= 10 - 2*2 - 3*1 >= 3
    # x >= rhs - max_act(y,z) 
    # x >= min_slack + act(x)
    coeffs = [1, 2, 3]
    lbs = [0, 0, 0]
    ubs = [10, 2, 1]
    rhs = 10
    sense = Greater

    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    lb = Coluna.Algorithm._var_lb_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test lb == 3
    
    ub = Coluna.Algorithm._var_ub_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test isinf(ub) && ub > 0
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row1)

function test_var_bounds_from_row2()
    # -3x + y + 2z <= 2
    # 0 <= x <= 10
    # 0 <= y <= 1
    # 0 <= z <= 1
    # therefore -3x + ub_y + 2*ub_z <= 2
    #           -3x + 1 + 2*1 <= 2
    #           -3x <= -1
    #           x >= 1/3
    coeffs = [-3, 1, 2]
    lbs = [0, 0, 0]
    ubs = [10, 1, 1]
    rhs = 2
    sense = Less

    min_slack = rhs - transpose(coeffs) * [lbs[1], ubs[2], ubs[3]]
    max_slack = rhs - transpose(coeffs) * [ubs[1], lbs[2], lbs[3]]

    lb = Coluna.Algorithm._var_lb_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test lb == 1/3

    ub = Coluna.Algorithm._var_ub_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test isinf(ub) && ub > 0
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row2)


function test_var_bounds_from_row3()
    # 2x + 3y - 4z <= 9
    # 0 <= x <= 10
    # 4 <= y <= 8
    # 0 <= z <= 1
    # therefore 2x + 3*lb_y - 4*ub_z <= 9
    #           2x + 3*4 - 4*1 <= 9
    #           2x <= 9 - 12 + 4
    #           2x <= 1

    coeffs = [2, 3, -4]
    lbs = [0, 4, 0]
    ubs = [10, 8, 1]
    rhs = 9
    sense = Less

    min_slack = rhs - transpose(coeffs) * [ubs[1], ubs[2], lbs[3]]
    max_slack = rhs - transpose(coeffs) * [lbs[1], lbs[2], ubs[3]]

    lb = Coluna.Algorithm._var_lb_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test isinf(lb) && lb < 0

    ub = Coluna.Algorithm._var_ub_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test ub == 1/2
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row3)

function test_var_bounds_from_row4()
    # -2x + 2y + 3z >= 10
    # -10 <= x <= 0
    # 1 <= y <= 2
    # 1 <= z <= 2
    # therefore -2*x + 2*lb_y + 3*lb_z >= 10
    #           -2*x + 2*1 + 3*1 >= 10
    #           -2*x >= 10 - 2 - 3
    #           -2*x >= 5
    coeffs = [-2, 2, 3]
    lbs = [-10, 1, 1]
    ubs = [0, 2, 2]
    rhs = 10
    sense = Greater

    min_slack = rhs - transpose(coeffs) * [lbs[1], ubs[2], ubs[3]]
    max_slack = rhs - transpose(coeffs) * [ubs[1], lbs[2], lbs[3]]

    lb = Coluna.Algorithm._var_lb_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test lb == -Inf

    ub = Coluna.Algorithm._var_ub_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test ub == -5/2
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row4)

function test_var_bounds_from_row5()
    # 2x + 3y + 4z = 5
    # -5 <= x <= 3
    # 0 <= y <= 1
    # 0 <= z <= 1

    # Sense1:
    # 2x + 3y + 4z >= 5
    # 2x + 3*ub_y + 4*ub_z >= 5
    # 2x + 3*1 + 4*1 >= 5
    # 2x >= -2

    # Sense 2:
    # 2x + 3y + 4z <= 5
    # 2x + 3*lb_y + 4*lb_z <= 5
    # 2x + 3*0 + 4*0 <= 5
    # 2x <= 5

    coeffs = [2, 3, 4]
    lbs = [-5, 0, 0]
    ubs = [3, 1, 1]
    rhs = 5
    sense = Equal

    min_slack = rhs - transpose(coeffs) * ubs
    max_slack = rhs - transpose(coeffs) * lbs

    lb = Coluna.Algorithm._var_lb_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test lb == -1

    ub = Coluna.Algorithm._var_ub_from_row(sense, min_slack, max_slack, coeffs[1], lbs[1], ubs[1])
    @test ub == 5/2
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row5)

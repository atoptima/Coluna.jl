function test_lb_precision()
    z = 1.19999999999999999
    a = 1.2 + 1e-5
    b = 1.2 + 1e-6
    c = 0.30000000000000004 # floating point error
    d = 0.30000000000000008 # floating point error
    e = 0.29999999999999998 # floating point error
    f = 0.29999999999999994 # floating point error

    @test Coluna.Algorithm._lb_prec(z) == 1.2
    @test Coluna.Algorithm._lb_prec(a) == a
    @test Coluna.Algorithm._lb_prec(b) == 1.2
    @test Coluna.Algorithm._lb_prec(c) == 0.3
    @test Coluna.Algorithm._lb_prec(d) == 0.3
    @test Coluna.Algorithm._lb_prec(e) == 0.3
    @test Coluna.Algorithm._lb_prec(f) == 0.3
end
register!(unit_tests, "presolve_helper", test_lb_precision)

function test_ub_precision()
    z = 1.20000000000000001
    a = 1.2 - 1e-5
    b = 1.2 - 1e-6
    c = 0.30000000000000004 # floating point error
    d = 0.30000000000000008 # floating point error
    e = 0.29999999999999998 # floating point error
    f = 0.29999999999999994 # floating point error

    @test Coluna.Algorithm._ub_prec(z) == 1.2
    @test Coluna.Algorithm._ub_prec(a) == a
    @test Coluna.Algorithm._ub_prec(b) == 1.2
    @test Coluna.Algorithm._ub_prec(c) == 0.3
    @test Coluna.Algorithm._ub_prec(d) == 0.3
    @test Coluna.Algorithm._ub_prec(e) == 0.3
    @test Coluna.Algorithm._ub_prec(f) == 0.3
end
register!(unit_tests, "presolve_helper", test_ub_precision)

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
    partial_sol = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1.0, 1.0)
    @test form.nb_vars == 7
    @test form.nb_constrs == 6
    @test all(form.col_major_coef_matrix .== coef_matrix)
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
    partial_sol = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)

    # Deactivate some rows.
    rows_to_deactivate = [1, 3, 6]
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}()

    form2, _, _, _ = Coluna.Algorithm.PresolveFormRepr(
        form, rows_to_deactivate, tightened_bounds, 1.0, 1.0;
        store_unpropagated_partial_sol = false
    )
    @test form2.nb_vars == 7
    @test form2.nb_constrs == 3
    @test all(form2.col_major_coef_matrix .== coef_matrix[[2, 4, 5], :])
    @test all(form2.rhs .== rhs[[2, 4, 5]] - [1*2 - 1, 2*2 - 4, 2*2 - 4])
    @test all(form2.sense .== sense[[2, 4, 5]])
    @test all(form2.lbs .== [0, 0, 0, 0, -1, -Inf, 0])
    @test all(form2.ubs .== [9, Inf, 1, 1, 1, 0, 1])
    @test all(form2.partial_solution .== [1, 0, 2, 1, 0, 0, 0])
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
    partial_sol = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)

    # Deactivate some rows.
    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int,Tuple{Float64, Bool, Float64, Bool}}()

    # Fixed variables:
    #      -1  - 2.5  # <= 4  ->  7.5
    #      1   + 2.5  # >= -4 -> -7.5
    # 10              # == 1  ->   -9
    #      2          # >= 2  ->    0
    #      2          # <= 1  ->   -1
    # 10+  3     -1   # == 6  ->   -6

    # Lower bound reduction:
    # x2 = 2, x4 = 1
    #  <= 7.5 - 1       -> 6.5
    #  >= -7.5 + 1      -> -6.5
    #  == -9            -> -9
    #  >= 0 - 2 + 4     -> 2
    #  <= -1 - 2 + 4    -> 1
    #  == -6 +2*2 - 5.5 -> -7.5

    form2, _, _, _ = Coluna.Algorithm.PresolveFormRepr(
        form, rows_to_deactivate, tightened_bounds, 1.0, 1.0;
        store_unpropagated_partial_sol = false
    )
    @test form2.nb_vars == 3
    @test form2.nb_constrs == 6
    @test all(form2.col_major_coef_matrix .== coef_matrix[:, [2, 4, 5]])
    @test all(form2.rhs .== [6.5, -6.5, -9, 2, 1, -7.5])
    @test all(form2.sense .== sense)
    @test all(form2.lbs .== [0, 0, -1]) # Vars 2, 4 & 5
    @test all(form2.ubs .== [1, 1, 1]) # Vars 2, 4, & 5
    @test all(form2.partial_solution .== [2, 1, 0])
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
    partial_sol = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1.0, 1.0)

    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int,Tuple{Float64, Bool, Float64, Bool}}(
        1 => (1, false, 2, true),
        2 => (0, true, 1, true),
        3 => (-1, false, 3, false),
        6 => (0.5, true, 0.5, true) # the flag forces the update!
    )
    form2, _, _, _ = Coluna.Algorithm.PresolveFormRepr(
        form, rows_to_deactivate, tightened_bounds, 1.0, 1.0;
        store_unpropagated_partial_sol = false
    )
    @test form2.nb_vars == 6
    @test form2.nb_constrs == 6
    @test all(form2.col_major_coef_matrix .== coef_matrix[:, [1, 2, 3, 4, 5, 7]])
    @test all(form2.rhs .== [4.5, -4.5, 0.0, 2.0, 1.0, -7.0])
    @test all(form2.sense .== sense)
    @test all(form2.lbs .== [0, 0, 0, 0, -1, 0])
    @test all(form2.ubs .== [1, 1, 1, 1, 1, 1])
    @test all(form2.partial_solution .== [1, 0, 2, 1, 0, 0])
end
register!(unit_tests, "presolve_helper", test_presolve_builder4)

function test_presolve_builder5()
    # 2x1 + 3x2 - 2x3 >= 2
    # 3x1 - 4x2 + x3 >= 5
    
    coef_matrix = sparse([
        2  3 -2
        3 -4  1
    ])
    rhs = [2, 5]
    sense = [Greater, Greater]
    lbs = [0, 0, -3]
    ubs = [Inf, Inf, 3]
    partial_sol = [1, 1, 0]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)
    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int,Tuple{Float64, Bool, Float64, Bool}}(
        1 => (1, true, Inf, false),
        2 => (1, true, Inf, false),
        3 => (1, true, 2, true)
    )

    form2, _, _, _ = Coluna.Algorithm.PresolveFormRepr(
        form, rows_to_deactivate, tightened_bounds, 1.0, 1.0;
        store_unpropagated_partial_sol = false
    )
    @test form2.nb_vars == 3
    @test form2.nb_constrs == 2
    @test all(form2.col_major_coef_matrix .== coef_matrix)
    @test all(form2.rhs .== ([2, 5] - [2 + 3 - 2, 3 - 4 + 1]))
    @test all(form2.sense .== sense)
    @test all(form2.lbs .== [0, 0, 0])
    @test all(form2.ubs .== [Inf, Inf, 1])
    @test all(form2.partial_solution .== [2, 2, 1])
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
    partial_sol = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)

    @test Coluna.Algorithm.row_min_activity(form, 1) == 0 + 0 - 1 * ubs[3] + 1 * lbs[4] + 0 + 1 * lbs[6] + 2.5 * lbs[7]
    @test Coluna.Algorithm.row_max_activity(form, 1) == 0 + 0 - 1 * lbs[3] + 1 * ubs[4] + 0 + 1 * ubs[6] + 2.5 * ubs[7]
    @test Coluna.Algorithm.row_min_activity(form, 2) == 0 + 0 + 1 * lbs[3] - 1 * ubs[4] + 0 - 1 * ubs[6] - 2.5 * ubs[7]
    @test Coluna.Algorithm.row_max_activity(form, 2) == 0 + 0 + 1 * ubs[3] - 1 * lbs[4] + 0 - 1 * lbs[6] - 2.5 * lbs[7]
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
    partial_sol = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)

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
    # -x - 2y - 3z <= -10
    # 0 <= x <= 10
    # 0 <= y <= 2
    # 0 <= z <= 1
    # therefore x >= 10 - 2*2 - 3*1 >= 3
    # x >= rhs - max_act(y,z)

    coef_matrix = sparse([1 2 3; -1 -2 -3;])
    rhs = [10, -10]
    sense = [Greater; Less]
    lbs = [0, 0, 0]
    ubs = [10, 2, 1]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, 1.0)
    @test lb == 3
    
    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, 1.0)
    @test isinf(ub) && ub > 0

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[2], min_slack, max_slack, -1.0)
    @test lb == 3

    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, -1.0)
    @test isinf(ub) && ub > 0
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row1)

function test_var_bounds_from_row2()
    # -3x + y + 2z <= 2
    #  3x - y - 2z >= -2
    # 0 <= x <= 10
    # 0 <= y <= 1
    # 0 <= z <= 1
    # therefore -3x <= 2 - y - 2z
    #           3x >= -2 + y + 2z
    #           3x >= -2 + 0 + 2*0
    #           x >= -2/3
    coef_matrix = sparse([-3 1 2; 3 -1 -2])
    rhs = [2, -2]
    sense = [Less, Greater]
    lbs = [0, 0, 0]
    ubs = [10, 1, 1]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, -3)
    @test lb == -2/3

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, -3)
    @test isinf(ub) && ub > 0

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[2], min_slack, max_slack, 3)
    @test lb == -2/3

    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, 3)
    @test isinf(ub) && ub > 0
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row2)

function test_var_bounds_from_row3()
    # 2x + 3y - 4z <= 9
    # -2x - 3y + 4z >= -9
    # 0 <= x <= 10
    # 4 <= y <= 8
    # 0 <= z <= 1
    # therefore 2x <= 9 - 3y + 4z
    #           2x <= 9 - 12 + 4
    #           2x <= 1

    coef_matrix = sparse([2 3 -4; -2 -3 4;])
    lbs = [0, 4, 0]
    ubs = [10, 8, 1]
    rhs = [9, -9]
    sense = [Less, Greater]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, 2)
    @test isinf(lb) && lb < 0

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, 2)
    @test ub == 1/2

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[2], min_slack, max_slack, -2)
    @test isinf(lb) && lb < 0

    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, -2)
    @test ub == 1/2
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row3)

function test_var_bounds_from_row4()
    # -2x + 2y + 3z >= 10
    # 2x - 2y - 3z <= 10
    # -10 <= x <= 0
    # 1 <= y <= 2
    # 1 <= z <= 2
    # therefore -2*x >= 10 - 2y - 3z
    #           2*x <= -10 + 2y + 3z
    #           2*x <= -10 + 2*2 + 3*2
    #           x <= 0
    coef_matrix = sparse([-2 2 3; 2 -2 -3])
    lbs = [-10, 1, 1]
    ubs = [0, 2, 2]
    rhs = [10, -10]
    sense = [Greater, Less]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, -2)
    @test lb == -Inf

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, -2)
    @test ub == 0

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[2], min_slack, max_slack, 2)
    @test lb == -Inf

    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, 2)
    @test ub == 0
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row4)

function test_var_bounds_from_row5()
    # 2x + 3y + 4z = 5
    # -5 <= x <= 3
    # 0 <= y <= 1
    # 0 <= z <= 1

    # Sense1:
    # 2x + 3y + 4z >= 5
    # 2x >= 5 - 3y - 4z
    # 2x >= -2

    # Sense 2:
    # 2x + 3y + 4z <= 5
    # 2x <= 5 - 3y - 4z
    # 2x <= 5

    coef_matrix = sparse([2 3 4;])
    lbs = [-5, 0, 0]
    ubs = [3, 1, 1]
    rhs = [5]
    sense = [Equal]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, 2)
    @test lb == -1

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, 2)
    @test ub == 5/2
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row5)

function test_var_bounds_from_row6()
    # x1 + x2 >= 1 (row 1)
    # y1 + y2 >= 1 (row 2)
    # 0 <= x1 <= 0.5
    # x2 >= 0
    # 0 <= y1 <= 0.3
    # y2 >= 0

    coef_matrix = sparse([
        1 1 0 0;
        0 0 1 1
    ])
    lbs = [0, 0, 0, 0]
    ubs = [0.5, Inf, 0.3, Inf]
    sense = [Greater, Greater]
    rhs = [1, 1]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack1 = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 2)
    max_slack1 = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 2)

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack1, max_slack1, 1)
    @test lb == 0.5

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack1, max_slack1, 1)
    @test ub == Inf

    min_slack2 = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 4)
    max_slack2 = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 4)

    lb = Coluna.Algorithm._var_lb_from_row(sense[2], min_slack2, max_slack2, 1)
    @test lb == 0.7

    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack2, max_slack2, 1)
    @test ub == Inf
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row6)

function test_var_bounds_from_row7()
    # -2x + y + z >= 150
    # -x + y + z <= 600
    # x == 10
    # y >= 0
    # z >= 0

    coef_matrix = sparse([-2 1 1; -1 1 1])
    lbs = [10, 0, 0]
    ubs = [10, Inf, Inf]
    rhs = [150, 600]
    sense = [Greater, Less]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    # -2x + y + z >= 150
    # -2x >= 150 - y - z
    # 2x <= -150 + y + z
    # x <= Inf

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, -2)
    @test isinf(lb) && lb < 0

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, -2)
    @test isinf(ub) && ub > 0

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 1)

    # -x + y + z <= 600
    # -x <= 600 - y - z
    # x >= -600 + y + z
    # x >= -600

    lb = Coluna.Algorithm._var_lb_from_row(sense[2], min_slack, max_slack, -1)
    @test lb == -600
    
    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, -1)
    @test isinf(ub) && ub > 0
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row7)

function test_var_bounds_from_row8() # this was producing a bug
    # 2x + y + z <= 1
    #      x == 2
    #      y >= 0
    #      z >= 0

    coef_matrix = sparse([2 1 1;])
    lbs = [2, 0, 0]
    ubs = [2, Inf, Inf]
    rhs = [1]
    sense = [Less]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    # 2x <= 1 - y - z
    # x <= 1/2
    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, 2)
    @test lb == -Inf

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, 2)
    @test ub == 1/2
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row8)

function test_var_bounds_from_row9()
    # x + y + a >= 1
    # x + y <= 1
    # x + y >= 0
    # x >= 0
    # y >= 1
    # a >= 0

    coef_matrix = sparse([1 1 1; 1 1 0; 1 1 0])
    lbs = [0, 1, 0]
    ubs = [Inf, Inf, Inf]
    rhs = [1, 1, 0]
    sense = [Greater, Less, Greater]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 1)

    # x <= 1 - y
    # x <= 0
    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, 1)
    @test ub == 0

    min_slack = Coluna.Algorithm.row_min_slack(form, 2, col -> col == 2)
    max_slack = Coluna.Algorithm.row_max_slack(form, 2, col -> col == 2)
    # y <= 1 - x
    # y <= 0
    ub = Coluna.Algorithm._var_ub_from_row(sense[2], min_slack, max_slack, 1)
    @test ub == 1

    result = Coluna.Algorithm.bounds_tightening(form)
    @test result[1] === (0.0, false, 0.0, true) 
    @test result[2] === (1.0, false, 1.0, true)
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row9)

function test_var_bounds_from_row10()
    # y2
    #  + 1.0 x + 1.0 y1 - 1.0 y2 + 1.0 z1 - 1.0 z2  == 0.0
    # 0.0 <= x <= Inf (Integ | MasterRepPricingVar | false)
    # 0.0 <= y1 <= Inf (Continuous | MasterArtVar | true)
    # 0.0 <= y2 <= Inf (Continuous | MasterArtVar | true)
    # 0.0 <= z1 <= Inf (Continuous | MasterArtVar | true)
    # 0.0 <= z2 <= Inf (Continuous | MasterArtVar | true)

    coef_matrix = sparse([1 1 -1 1 -1])
    lbs = [0, 0, 0, 0, 0]
    ubs = [Inf, Inf, Inf, Inf, Inf]
    rhs = [0]
    sense = [Equal]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 3)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 3)

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, 1)
    @test ub == Inf

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, 1)
    @test lb == -Inf
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row10)

function test_var_bounds_from_row11()
    # - w - x + y + z = 0
    #

    # w = y + z -x
    # lb: -x -> 
    # donc

    coef_matrix = sparse([-1 -1 1 1])
    lbs = [0, 0, 0, 0]
    ubs = [Inf, Inf, Inf, Inf]
    rhs = [0]
    sense = [Equal]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 0, 0)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, -1)
    @test ub == Inf

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, -1)
    @test lb == -Inf
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row11)

function test_var_bounds_from_row12()
    # 0x + y + z <= 5
    # 0 <= x <= 2
    # 1 <= y <= 3
    # 0 <= z <= 6

    coef_matrix = sparse([0 1 1;])
    lbs = [0, 1, 0]
    ubs = [2, 3, 6]
    rhs = [5]
    sense = [Less]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_solution, 1, 1)

    min_slack = Coluna.Algorithm.row_min_slack(form, 1, col -> col == 1)
    max_slack = Coluna.Algorithm.row_max_slack(form, 1, col -> col == 1)

    ub = Coluna.Algorithm._var_ub_from_row(sense[1], min_slack, max_slack, 0)
    @test ub == Inf

    lb = Coluna.Algorithm._var_lb_from_row(sense[1], min_slack, max_slack, 0)
    @test lb == -Inf
end
register!(unit_tests, "presolve_helper", test_var_bounds_from_row12)

function test_uninvolved_vars1()
    # 0x + y + z <= 5
    # 0 <= x <= 2
    # 1 <= y <= 3
    # 0 <= z <= 6

    coef_matrix = sparse([0 1 1;])
    lbs = [0, 1, 0]
    ubs = [2, 3, 6]
    rhs = [5]
    sense = [Less]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, ubs, lbs, partial_solution, 1, 1)

    cols = Coluna.Algorithm.find_uninvolved_vars(form.col_major_coef_matrix)

    @test cols == [1]
end
register!(unit_tests, "presolve_helper", test_uninvolved_vars1)

function test_uninvolved_vars2()
    # x + y + z <= 5
    # 0 <= x <= 2
    # 1 <= y <= 3
    # 0 <= z <= 6

    coef_matrix = sparse([1 1 1;])
    lbs = [0, 1, 0]
    ubs = [2, 3, 6]
    rhs = [5]
    sense = [Less]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, ubs, lbs, partial_solution, 1, 1)

    cols = Coluna.Algorithm.find_uninvolved_vars(form.col_major_coef_matrix)

    @test cols == []
end
register!(unit_tests, "presolve_helper", test_uninvolved_vars2)

function test_uninvolved_vars3()
    # w, x, y, z
    
    #    x        >= 2
    #    x + y    >= 5

    coef_matrix = sparse([0 1 0 0; 0 1 1 0])
    lbs = [0, 0, 0, 0]
    ubs = [Inf, Inf, Inf, Inf]
    rhs = [2, 5]
    sense = [Greater, Greater]
    partial_solution = zeros(Float64, length(lbs))

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, ubs, lbs, partial_solution, 1, 1)

    cols = Coluna.Algorithm.find_uninvolved_vars(form.col_major_coef_matrix)
    @test cols == [1, 4]
end
register!(unit_tests, "presolve_helper", test_uninvolved_vars3)
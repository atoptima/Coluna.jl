function test_partial_solution1()
    # 2x + 3y <= 4
    # 0 <= x <= 5
    # 0 <= y <= 6
    # with partial sol: x1 = 1, x2 = 2

    coef_matrix = sparse([2 3;])
    rhs = [4.0]
    sense = [Less]
    lbs = [0.0, 0.0]
    ubs = [5.0, 6.0]
    partial_sol = [1.0, 2.0]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)
    @test form.nb_vars == 2
    @test form.nb_constrs == 1
    @test all(form.col_major_coef_matrix .== coef_matrix)
    @test all(form.rhs .== rhs)
    @test all(form.sense .== sense)
    @test all(form.lbs .== lbs)
    @test all(form.ubs .== ubs)
    @test all(form.partial_solution .== partial_sol)

    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}(
        1 => (1, true, Inf, false),
        2 => (2, true, Inf, false)
    )

    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, tightened_bounds, 1, 1)
    @test form2.nb_vars == 2
    @test form2.nb_constrs == 1
    @test all(form2.col_major_coef_matrix .== coef_matrix)
    @test form2.rhs == [-4]
    @test form2.sense == [Less]
    @test form2.lbs == [0.0, 0.0]
    @test form2.ubs == [4.0, 4.0]
    @test form2.partial_solution == [2.0, 4.0]
end
register!(unit_tests, "presolve_partial_sol", test_partial_solution1)

function test_partial_solution2()
    # 2x + 3y <= 5
    # x >= 0
    # y >= 0
    # with partial sol: x1 = 2, x2 = 1

    coef_matrix = sparse([2 3;])
    rhs = [5.0]
    sense = [Less]
    lbs = [0.0, 0.0]
    ubs = [Inf, Inf]
    partial_sol = [2.0, 1.0]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)
    @test form.nb_vars == 2
    @test form.nb_constrs == 1
    @test all(form.col_major_coef_matrix .== coef_matrix)
    @test all(form.rhs .== rhs)
    @test all(form.sense .== sense)
    @test all(form.lbs .== lbs)
    @test all(form.ubs .== ubs)
    @test all(form.partial_solution .== partial_sol)

    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}(
        1 => (1, true, Inf, false),
        2 => (2, true, Inf, false)
    )

    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, tightened_bounds, 1, 1)
    @test form2.nb_vars == 2
    @test form2.nb_constrs == 1
    @test all(form2.col_major_coef_matrix .== coef_matrix)
    @test form2.rhs == [-3]
    @test form2.sense == [Less]
    @test all(form2.lbs .== [0.0, 0.0])
    @test all(form2.ubs .== [Inf, Inf])
    @test all(form2.partial_solution .== [3.0, 3.0])
end
register!(unit_tests, "presolve_partial_sol", test_partial_solution2)

function test_partial_solution3()
    # 2x + 3y <= 5
    # x + y >= 2
    # -5 <= x <= 5
    # -10 <= y <= 10

    coef_matrix = sparse([2 3; 1 1;])
    rhs = [5.0, 2.0]
    sense = [Less, Greater]
    lbs = [-5.0, -10.0]
    ubs = [5.0, 10.0]
    partial_sol = [0.0, 0.0]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)
    @test form.nb_vars == 2
    @test form.nb_constrs == 2
    @test all(form.col_major_coef_matrix .== coef_matrix)
    @test all(form.rhs .== rhs)
    @test all(form.sense .== sense)
    @test all(form.lbs .== lbs)
    @test all(form.ubs .== ubs)
    @test all(form.partial_solution .== partial_sol)

    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}(
        1 => (-5, false, -3, true),
        2 => (-10, false, 8, true)
    )

    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, tightened_bounds, 1, 1)
    @test form2.nb_vars == 2
    @test form2.nb_constrs == 2
    @test all(form2.col_major_coef_matrix .== coef_matrix)
    @test all(form2.rhs .== [11, 5])
    @test all(form2.lbs .== [-2.0, -10.0])
    @test all(form2.ubs .== [-0.0, 8.0])
    @test all(form2.partial_solution .== [-3.0, 0.0])
end
register!(unit_tests, "presolve_partial_sol", test_partial_solution3)

function test_partial_solution4()
    # 2x + 3y <= 5
    # x + y >= 2
    # x <= 0 
    # y <= 0

    coef_matrix = sparse([2 3; 1 1;])
    rhs = [5.0, 2.0]
    sense = [Less, Greater]
    lbs = [-Inf, -Inf]
    ubs = [0.0, 0.0]
    partial_sol = [0.0, 0.0]

    form = Coluna.Algorithm.PresolveFormRepr(coef_matrix, rhs, sense, lbs, ubs, partial_sol, 1, 1)
    @test form.nb_vars == 2
    @test form.nb_constrs == 2
    @test all(form.col_major_coef_matrix .== coef_matrix)
    @test all(form.rhs .== rhs)
    @test all(form.sense .== sense)
    @test all(form.lbs .== lbs)
    @test all(form.ubs .== ubs)
    @test all(form.partial_solution .== partial_sol)
    
    rows_to_deactivate = Int[]
    tightened_bounds = Dict{Int, Tuple{Float64, Bool, Float64, Bool}}(
        1 => (-Inf, false, -1.0, true),
        2 => (-Inf, false, -1.0, true)
    )

    form2 = Coluna.Algorithm.PresolveFormRepr(form, rows_to_deactivate, tightened_bounds, 1, 1)
    @test form2.nb_vars == 2
    @test form2.nb_constrs == 2
    @test all(form2.col_major_coef_matrix .== coef_matrix)
    @test all(form2.rhs .== [10, 4])
    @test all(form2.lbs .== [-Inf, -Inf])
    @test all(form2.ubs .== [0.0, 0.0])
    @test all(form2.partial_solution .== [-1.0, -1.0])
end
register!(unit_tests, "presolve_partial_sol", test_partial_solution4)
# Minimization and test all constraint senses
form1() = """
master
    min
    3x1 + 2x2 + 5x3 + 4y1 + 3y2 + 5y3
    s.t.
    x1 + x2 + x3 + y1 + y2 + y3  >= 10
    x1 + 2x2     + y1 + 2y2      <= 100
    x1 +     3x3 + y1 +    + 3y3 == 100
    
    integer
        representatives
            x1, x2, x3, y1, y2, y3
    
    bounds
        x1 >= 0
        x2 >= 0
        x3 >= 0
        y1 >= 0
        y2 >= 0
        y3 >= 0
"""

function get_name_to_varids(form)
    d = Dict{String, ClMP.VarId}()
    for (varid, var) in ClMP.getvars(form)
        d[ClMP.getname(form, var)] = varid
    end
    return d
end

function get_name_to_constrids(form)
    d = Dict{String, ClMP.ConstrId}()
    for (constrid, constr) in ClMP.getconstrs(form)
        d[ClMP.getname(form, constr)] = constrid
    end
    return d
end

# Simple case with only subproblem representatives variables.
function test_reduced_costs_calculation_helper()
    _, master, _, _, _ = reformfromstring(form1())
    vids = get_name_to_varids(master)
    cids = get_name_to_constrids(master)
    
    helper = ClA.ReducedCostsCalculationHelper(master)
    @test helper.c[vids["x1"]] == 3
    @test helper.c[vids["x2"]] == 2
    @test helper.c[vids["x3"]] == 5
    @test helper.c[vids["y1"]] == 4
    @test helper.c[vids["y2"]] == 3
    @test helper.c[vids["y3"]] == 5

    @test helper.A[cids["c1"], vids["x1"]] == 1
    @test helper.A[cids["c1"], vids["x2"]] == 1
    @test helper.A[cids["c1"], vids["x3"]] == 1
    @test helper.A[cids["c1"], vids["y1"]] == 1
    @test helper.A[cids["c1"], vids["y2"]] == 1
    @test helper.A[cids["c1"], vids["y3"]] == 1

    @test helper.A[cids["c2"], vids["x1"]] == 1
    @test helper.A[cids["c2"], vids["x2"]] == 2
    @test helper.A[cids["c2"], vids["y1"]] == 1
    @test helper.A[cids["c2"], vids["y2"]] == 2

    @test helper.A[cids["c3"], vids["x1"]] == 1
    @test helper.A[cids["c3"], vids["x3"]] == 3
    @test helper.A[cids["c3"], vids["y1"]] == 1
    @test helper.A[cids["c3"], vids["y3"]] == 3
end
register!(unit_tests, "colgen_default", test_reduced_costs_calculation_helper)


# All the tests are based on the Generalized Assignment problem.
# x_jm = 1 if job j is assigned to machine m
gap1() =  """
    master
        min
        x_11 + 3x_12 + 4x_13 + 5x_14 + 6x_15 + 3x_21 + x_22 + 2x_23 + 3x_24 + 4x_25
        s.t.
        x_11 + x_12 + x_13 + x_14 + x_15 >= 1
        x_21 + x_22 + x_23 + x_24 + x_25 >= 1

    dw_sp
        min
        x_11 + 3x_12 + 4x_13 + 5x_14 + 6x_15
        s.t.
        2x_11 + 3x_12 + 4x_13 + 5x_14 + 6x_15 <= 15

    dw_sp
        min
        3x_21 + x_22 + 2x_23 + 3x_24 + 4x_25
        s.t.
        3x_21 + 4x_22 + 3x_23 + 2x_24 + 4x_25 <= 20

    integer
        representatives
            x_11, x_12, x_13, x_14, x_15, x_21, x_22, x_23, x_24, x_25

    bounds
        0 <= x_11 <= 1
        0 <= x_12 <= 1
        0 <= x_13 <= 1
        0 <= x_14 <= 1
        0 <= x_15 <= 1
        0 <= x_21 <= 1
        0 <= x_22 <= 1
        0 <= x_23 <= 1
        0 <= x_24 <= 1
        0 <= x_25 <= 1
    """

function test_colgen_iteration()
    env, master, sps, _, reform = reformfromstring(gap1())
    # vids = get_name_to_varids(master)
    # cids = get_name_to_constrids(master)

    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    ClMP.push_optimizer!(master, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    ClMP.relax_integrality!(master)
    for sp in sps
        ClMP.push_optimizer!(sp, () -> ClA.MoiOptimizer(GLPK.Optimizer()))
    end
    ColGen.run_colgen_iteration!(ctx, ClA.ColGenPhase3(), env)
end
register!(unit_tests, "colgen_default", test_colgen_iteration)



#         master
#             min
#             7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45 + 28λ1 + 25λ2 + 21λ3 + 19λ4 + 22λ5 + 18λ6 + 28λ7
#             s.t.
#             x_12 + x_13 + x_14 + x_15 + 2λ1 + 2λ2 + 2λ3 + 2λ4 + 2λ5 + 2λ6 + 2λ7 == 2
#             x_12 + x_23 + x_24 + x_25 + 2λ1 + 2λ2 + 2λ3 + 1λ4 + 1λ5 + 2λ6 + 3λ7 == 2
#             x_13 + x_23 + x_34 + x_35 + 2λ1 + 3λ2 + 2λ3 + 3λ4 + 2λ5 + 3λ6 + 1λ7 == 2
#             x_14 + x_24 + x_34 + x_45 + 2λ1 + 2λ2 + 3λ3 + 3λ4 + 3λ5 + 1λ6 + 1λ7 == 2
#             x_15 + x_25 + x_35 + x_45 + 2λ1 + 1λ2 + 1λ3 + 1λ4 + 2λ5 + 2λ6 + 3λ7 == 2

#         dw_sp
#             min
#             7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45
#             s.t.
#             x_12 + x_13 + x_14 + x_15 == 1

#         continuous
#             columns
#                 λ1, λ2, λ3, λ4, λ5, λ6, λ7

#         integer
#             representatives
#                 x_12, x_13, x_14, x_15, x_23, x_24, x_25, x_34, x_35, x_45

#         bounds
#             λ1 >= 0
#             λ2 >= 0
#             λ3 >= 0
#             λ4 >= 0
#             λ5 >= 0
#             λ6 >= 0
#             λ7 >= 0
#             x_12 >= 0
#             x_13 >= 0
#             x_14 >= 0
#             x_15 >= 0
#             x_23 >= 0
#             x_24 >= 0
#             x_25 >= 0
#             x_34 >= 0
#             x_35 >= 0
#             x_45 >= 0
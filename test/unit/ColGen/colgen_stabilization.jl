# Test the implementation of the stabilization procedure.

# Make sure the value of α is updated correctly after each misprice.
# The goal is to tend to 0.0 after a given number of misprices.
function test_misprice_schedule()
    smooth_factor = 1
    nb_misprices = 0
    α = 0.8
    for i in 1:10
        α = Coluna.Algorithm._misprice_schedule(smooth_factor, nb_misprices, α)
        nb_misprices += 1
        @show α
    end
    return
end
register!(unit_tests, "colgen_stabilization", test_misprice_schedule; f = true)

form_primal_solution() = """
    master
        min
        3x_11 + 2x_12 + 5x_13 + 2x_21 + x_22 +  x_23  + 4y1 + 3y2 + z1 + z2 + 0s1 + 0s2
        s.t.
        x_11  + x_12  + x_13  +  x_21 +                 y1 +  y2  + 2z1 + z2 >= 10
        x_11  + 2x_12 +          x_21 + 2x_22 + 3x_23 + y1 +  2y2 + z1       <= 100
        x_11  +         3x_13 +          x_22 +  x_23 + y1 +                 == 100
                                                        y1 +      + z1  + z2 <= 5  
        s1                                                                   >= 1 {MasterConvexityConstr}
        s1                                                                   <= 2 {MasterConvexityConstr}
        s2                                                                   >= 0 {MasterConvexityConstr}
        s2                                                                   <= 3 {MasterConvexityConstr}

    dw_sp
        min
        x_11 + x_12 + x_13 + y1 + 0s1
        s.t.
        x_11 + x_12 + x_13 + y1 >= 10

    dw_sp
        min
        x_21 + x_22 + x_23 + y2 + 0s2
        s.t.
        x_21 + x_22 + x_23 + y2 >= 10
        
        integer
            representatives
                x_11, x_12, x_13, x_21, x_22, x_23, y1, y2

            pure
                z1, z2

            pricing_setup
                s1, s2
        
        bounds
            x_11 >= 0
            x_12 >= 0
            x_13 >= 0
            x_21 >= 0
            x_22 >= 1
            x_23 >= 0
            1 <= y1 <= 2
            3 <= y2 <= 6
            z1 >= 0
            z2 >= 3
"""


function test_primal_solution()
    _, master, sps, _, _ = reformfromstring(form_primal_solution())

    sp1, sp2 = sps[2], sps[1]

    vids = get_name_to_varids(master)
    cids = get_name_to_constrids(master)

    pool = Coluna.Algorithm.ColumnsSet()

    sol1 = Coluna.MathProg.PrimalSolution(
        sp1,
        [vids["x_11"], vids["x_12"], vids["x_13"], vids["y1"], vids["s1"]],
        [1.0, 2.0, 3.0, 7.0, 1.0],
        11.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
    Coluna.Algorithm.add_primal_sol!(pool.subprob_primal_sols, sol1, false) # improving = true

    sol2 = Coluna.MathProg.PrimalSolution(
        sp2,
        [vids["x_21"], vids["x_22"], vids["x_23"], vids["y2"], vids["s2"]],
        [4.0, 4.0, 5.0, 10.0, 1.0],
        13.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
    Coluna.Algorithm.add_primal_sol!(pool.subprob_primal_sols, sol2, true)

    primal_sol = Coluna.Algorithm._primal_solution(master, pool, true)
    
    sp1_lb = 1.0
    sp2_ub = 3.0
    @test primal_sol[vids["x_11"]] == 1.0 * sp1_lb
    @test primal_sol[vids["x_12"]] == 2.0 * sp1_lb
    @test primal_sol[vids["x_13"]] == 3.0 * sp1_lb
    @test primal_sol[vids["x_21"]] == 4.0 * sp2_ub
    @test primal_sol[vids["x_22"]] == 4.0 * sp2_ub
    @test primal_sol[vids["x_23"]] == 5.0 * sp2_ub
    @test primal_sol[vids["y1"]] == 7.0 * sp1_lb
    @test primal_sol[vids["y2"]] == 10.0 * sp2_ub
    @test primal_sol[vids["s1"]] == 1.0 * sp1_lb
    @test primal_sol[vids["s2"]] == 1.0 * sp2_ub
    @test primal_sol[vids["z1"]] == 0.0 # TODO: not sure about this test
    @test primal_sol[vids["z2"]] == 0.0 # TODO: not sure about this test
    return
end
register!(unit_tests, "colgen_stabilization", test_primal_solution; f = true)

# Make sure the angle is well computed.
function test_angle()

end
register!(unit_tests, "colgen_stabilization", test_angle; f = true)

function test_dynamic_alpha_schedule()

end
register!(unit_tests, "colgen_stabilization", test_dynamic_alpha_schedule; f = true)

# Mock implementation of the column generation to make sure the stabilization logic works
# as expected.

################################################################################
# Test the implementation of the stabilization procedure.
################################################################################

# Make sure the value of α is updated correctly after each misprice.
# The goal is to tend to 0.0 after a given number of misprices.
function test_misprice_schedule()
    smooth_factor = 1
    base_α = 0.8
    prev_α = 0.8
    for nb_misprices in 1:11
        α = Coluna.Algorithm._misprice_schedule(smooth_factor, nb_misprices, base_α)
        @test (prev_α > α) || (iszero(α) && iszero(prev_α))
        prev_α = α
    end
    return
end
register!(unit_tests, "colgen_stabilization", test_misprice_schedule)

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
register!(unit_tests, "colgen_stabilization", test_primal_solution)

form_primal_solution2() = """
    master
        min
        3x_11 + 2x_12 + 2x_21 + x_22 + z1 + z2 + 0s1 + 0s2
        s.t.
        x_11  + x_12  +  x_21 +         2z1 + z2  >= 10
        x_11  + 2x_12 +  x_21 + 2x_22 +  z1       <= 100
        x_11  +                  x_22 +           == 100
                                         z1  + z2 >= 5  
        s1                                        >= 1 {MasterConvexityConstr}
        s1                                        <= 2 {MasterConvexityConstr}
        s2                                        >= 0 {MasterConvexityConstr}
        s2                                        <= 3 {MasterConvexityConstr}

    dw_sp
        min
        x_11 + x_12 + 0s1
        s.t.
        x_11 + x_12  >= 10

    dw_sp
        min
        x_21 + x_22 + 0s2
        s.t.
        x_21 + x_22  >= 10
        
        integer
            representatives
                x_11, x_12, x_21, x_22

            pure
                z1, z2

            pricing_setup
                s1, s2
        
        bounds
            x_11 >= 0
            x_12 >= 0
            x_21 >= 0
            x_22 >= 1
            z1 >= 0
            z2 >= 3
"""

# We consider the master with the following coefficient matrix:
# master_coeff_matrix = [
#      1 1 1 0 1 1;
#      -1 -2 -1 -2 -1 0;
#      1 0 0 1 0 0;      # is it correct to handle an "==" constraint like this in subgradient computation?
#      0 0 0 0 1 1;
# ]
# the following rhs: rhs = [10, -100, 100, 5]

# We consider the primal solution: primal = [1, 2, 12, 12, 0, 0]
# The subgradient is therefore: rhs - master_coeff_matrix * primal = [-5, -59, 87, 5]
# We use the following stability center:  stab = [1, 2, 0, 1]

function _test_angle_primal_sol(master, sp1, sp2)
    vids = get_name_to_varids(master)
    pool = Coluna.Algorithm.ColumnsSet()

    sol1 = Coluna.MathProg.PrimalSolution(
        sp1,
        [vids["x_11"], vids["x_12"]],
        [1.0, 2.0],
        11.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
    Coluna.Algorithm.add_primal_sol!(pool.subprob_primal_sols, sol1, false) # improving = true

    sol2 = Coluna.MathProg.PrimalSolution(
        sp2,
        [vids["x_21"], vids["x_22"]],
        [4.0, 4.0],
        13.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
    Coluna.Algorithm.add_primal_sol!(pool.subprob_primal_sols, sol2, true)
    is_minimization = true
    primal_sol = Coluna.Algorithm._primal_solution(master, pool, is_minimization)
    return primal_sol
end

function _test_angle_stab_center(master)
    cids = get_name_to_constrids(master)
    return Coluna.MathProg.DualSolution(
        master,
        [cids["c1"], cids["c2"], cids["c4"]],
        [1.0, 2.0, 1.0],
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
end

function _data_for_dynamic_schedule_test()
    _, master, sps, _, _ = reformfromstring(form_primal_solution2())
    sp1, sp2 = sps[2], sps[1]
    cids = get_name_to_constrids(master)

    cur_stab_center = _test_angle_stab_center(master)

    h = Coluna.Algorithm.SubgradientCalculationHelper(master)
    is_minimization = true
    primal_sol = _test_angle_primal_sol(master, sp1, sp2)
    return master, cur_stab_center, h, primal_sol, is_minimization
end

# Make sure the angle is well computed.
# Here we test the can where the in and sep points are the same.
# In that case, we should decrease the value of α.
function test_angle_1()
    master, cur_stab_center, h, primal_sol, is_minimization = _data_for_dynamic_schedule_test()
    cids = get_name_to_constrids(master)
    smooth_dual_sol = Coluna.MathProg.DualSolution(
        master,
        [cids["c1"], cids["c2"], cids["c4"]],
        [1.0, 2.0, 1.0],
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )

    increase = Coluna.Algorithm._increase(smooth_dual_sol, cur_stab_center, h, primal_sol, is_minimization)
    @test increase == false
end
register!(unit_tests, "colgen_stabilization", test_angle_1)

# Let's consider the following sep point: sep = [5, 7, 0, 3]
# The direction will be [4, 5, 0, 2] and should lead to a negative cosinus for the angle.
# In that case, we need to increase the value of α.
function test_angle_2()
    master, cur_stab_center, h, primal_sol, is_minimization = _data_for_dynamic_schedule_test()
    cids = get_name_to_constrids(master)

    smooth_dual_sol = Coluna.MathProg.DualSolution(
        master,
        [cids["c1"], cids["c2"], cids["c4"]],
        [5.0, 7.0, 3.0],
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
    increase = Coluna.Algorithm._increase(smooth_dual_sol, cur_stab_center, h, primal_sol, is_minimization)
    @test increase == true
end
register!(unit_tests, "colgen_stabilization", test_angle_2)

# Let's consider the following sep point: sep = [5, 1, 10, 3]
# The direction will be [4, 1, 10, 2] and should lead to a positive cosinus for the angle.
# In that case, we need to decrease the value of α.
function test_angle_3()
    master, cur_stab_center, h, primal_sol, is_minimization = _data_for_dynamic_schedule_test()
    cids = get_name_to_constrids(master)

    smooth_dual_sol = Coluna.MathProg.DualSolution(
        master,
        [cids["c1"], cids["c2"], cids["c3"], cids["c4"]],
        [5.0, 1.0, 10.0, 3.0],
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )
    increase = Coluna.Algorithm._increase(smooth_dual_sol, cur_stab_center, h, primal_sol, is_minimization)
    @test increase == false
end
register!(unit_tests, "colgen_stabilization", test_angle_3)

function test_dynamic_alpha_schedule()
    for α in 0.1:0.1:0.9
        @test Coluna.Algorithm.f_incr(α) > α
        @test Coluna.Algorithm.f_decr(α) < α
    end
    @test Coluna.Algorithm.f_incr(1.0) - 1.0 < 1e-3
    @test Coluna.Algorithm.f_decr(0.0) < 1e-3


    master, cur_stab_center, h, primal_sol, is_minimization = _data_for_dynamic_schedule_test()
    cids = get_name_to_constrids(master)

    smooth_dual_sol_for_decrease = Coluna.MathProg.DualSolution(
        master,
        [cids["c1"], cids["c2"], cids["c3"], cids["c4"]],
        [5.0, 1.0, 10.0, 3.0],
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )

    smooth_dual_sol_for_increase = Coluna.MathProg.DualSolution(
        master,
        [cids["c1"], cids["c2"], cids["c4"]],
        [5.0, 7.0, 3.0],
        Coluna.MathProg.VarId[], Float64[], Coluna.MathProg.ActiveBound[],
        0.0,
        Coluna.MathProg.FEASIBLE_SOL
    )

    α = 0.8
    @test α > Coluna.Algorithm._dynamic_alpha_schedule(
        α, smooth_dual_sol_for_decrease, cur_stab_center, h, primal_sol, is_minimization
    )
    @test α < Coluna.Algorithm._dynamic_alpha_schedule(
        α, smooth_dual_sol_for_increase, cur_stab_center, h, primal_sol, is_minimization
    )
end
register!(unit_tests, "colgen_stabilization", test_dynamic_alpha_schedule)


################################################################################
# Test to make sure the generic code works
################################################################################
# Mock implementation of the column generation to make sure the stabilization logic works
# as expected.

mutable struct ColGenStabFlowStab
    nb_misprice::Int64
    nb_update_stab_after_master_done::Int64
    nb_update_stab_after_pricing_done::Int64
    nb_check_misprice::Int64
    nb_misprices_done::Int64
    nb_update_stab_after_iter_done::Int64
    ColGenStabFlowStab(nb_misprice) = new(nb_misprice, 0, 0, 0, 0, 0)
end

struct ColGenStabFlowRes end
struct ColGenStabFlowOutput end
struct ColGenStabFlowDualSol end
struct ColGenStabFlowPrimalSol end
struct ColGenStabFlowPricingStrategy end

mutable struct ColGenStabFlowCtx <: Coluna.ColGen.AbstractColGenContext
    nb_compute_dual_bound::Int64
    ColGenStabFlowCtx() = new(0)
end

ColGen.get_master(::ColGenStabFlowCtx) = nothing
ColGen.is_minimization(::ColGenStabFlowCtx) = true
ColGen.optimize_master_lp_problem!(master, ctx::ColGenStabFlowCtx, env) = ColGenStabFlowRes()
ColGen.colgen_iteration_output_type(::ColGenStabFlowCtx) = ColGenStabFlowOutput
ColGen.is_infeasible(::ColGenStabFlowRes) = false
ColGen.is_unbounded(::ColGenStabFlowRes) = false
ColGen.get_dual_sol(::ColGenStabFlowRes) = ones(Float64, 3)
ColGen.get_primal_sol(::ColGenStabFlowRes) = ColGenStabFlowPrimalSol()
ColGen.get_obj_val(::ColGenStabFlowRes) = 0.0
ColGen.isbetter(::ColGenStabFlowPrimalSol, p) = false
ColGen.get_reform(::ColGenStabFlowCtx) = nothing
ColGen.update_master_constrs_dual_vals!(::ColGenStabFlowCtx, phase, reform, dual_sol) = nothing
ColGen.get_subprob_var_orig_costs(::ColGenStabFlowCtx) = ones(Float64, 3)
ColGen.get_subprob_var_coef_matrix(::ColGenStabFlowCtx) = ones(Float64, 3, 3)
ColGen.update_reduced_costs!(::ColGenStabFlowCtx, phase, red_costs) = nothing

function ColGen.update_stabilization_after_master_optim!(stab::ColGenStabFlowStab, phase, mast_dual_sol)
    stab.nb_update_stab_after_master_done += 1
    return true
end

ColGen.get_master_dual_sol(stab::ColGenStabFlowStab, phase, mast_dual) = [0.5, 0.5, 0.5]
ColGen.set_of_columns(::ColGenStabFlowCtx) = []
ColGen.get_pricing_subprobs(::ColGenStabFlowCtx) = []
ColGen.get_pricing_strategy(::ColGenStabFlowCtx, phase) = ColGenStabFlowPricingStrategy()
ColGen.pricing_strategy_iterate(::ColGenStabFlowPricingStrategy) = nothing
ColGen.compute_dual_bound(ctx::ColGenStabFlowCtx, phase, bounds, mast_dual_sol) = ctx.nb_compute_dual_bound += 1

function ColGen.update_stabilization_after_pricing_optim!(stab::ColGenStabFlowStab, master, valid_db, pseudo_db, mast_dual_sol)
    @test mast_dual_sol == [1.0, 1.0, 1.0] # we need the out point in this method.
    stab.nb_update_stab_after_pricing_done += 1
    return true
end

function ColGen.check_misprice(stab::ColGenStabFlowStab, cols, mast_dual_sol)
    @test mast_dual_sol == [1.0, 1.0, 1.0] # we need the out point in this method.
    stab.nb_check_misprice += 1
    return stab.nb_check_misprice <= stab.nb_misprice
end

function ColGen.update_stabilization_after_misprice!(stab::ColGenStabFlowStab, mast_dual_sol)
    @test mast_dual_sol == [1.0, 1.0, 1.0] # we need the out point in this method.
    stab.nb_misprices_done += 1
end

function ColGen.insert_columns!(reform, context::ColGenStabFlowCtx, phase, generated_columns)
    return []
end

function ColGen.update_stabilization_after_iter!(stab::ColGenStabFlowStab, ctx, master, generated_columns, mast_dual_sol)
    @test mast_dual_sol == [1.0, 1.0, 1.0] # we need the out point in this method.
    stab.nb_update_stab_after_iter_done += 1
    return true
end

ColGen.new_iteration_output(::Type{<:ColGenStabFlowOutput}, args...) = nothing

function test_stabilization_flow_no_misprice()
    ctx = ColGenStabFlowCtx()
    phase = nothing
    stage = nothing
    env = nothing
    ip_primal_sol = nothing
    stab = ColGenStabFlowStab(0)
    res = Coluna.ColGen.run_colgen_iteration!(ctx, phase, stage, env, ip_primal_sol, stab)
    @test stab.nb_check_misprice == 1
    @test stab.nb_misprices_done == 0
    @test stab.nb_update_stab_after_iter_done == 1
    @test stab.nb_update_stab_after_master_done == 1
    @test stab.nb_update_stab_after_pricing_done == 1
end
register!(unit_tests, "colgen_stabilization", test_stabilization_flow_no_misprice)

function test_stabilization_flow_with_misprice()
    ctx = ColGenStabFlowCtx()
    phase = nothing
    stage = nothing
    env = nothing
    ip_primal_sol = nothing
    stab = ColGenStabFlowStab(10)
    res = Coluna.ColGen.run_colgen_iteration!(ctx, phase, stage, env, ip_primal_sol, stab)
    @test stab.nb_check_misprice == 10 + 1
    @test stab.nb_misprices_done == 10
    @test stab.nb_update_stab_after_iter_done == 1
    @test stab.nb_update_stab_after_master_done == 1
    @test stab.nb_update_stab_after_pricing_done == 10 + 1
end
register!(unit_tests, "colgen_stabilization", test_stabilization_flow_with_misprice)
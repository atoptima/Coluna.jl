function optstate_unit_tests()
    update_sol_tests()
    add_sol_tests()
    set_sol_tests()
end

function update_sol_tests()
    ############################################################################################
    # MinSense                                                                                 #
    ############################################################################################
    form = create_formulation!(Env(Coluna.Params()), Original())
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    state = OptimizationState(
        form, max_length_ip_primal_sols = 2.0,
        max_length_lp_primal_sols = 2.0, max_length_lp_dual_sols = 2.0
    )
    primalsol = PrimalSolution(form, [getid(var)], [2.0], 2.0, CB.UNKNOWN_FEASIBILITY)
    dualsol = DualSolution(form, [getid(constr)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY)

    ### ip primal
    update_ip_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.ip_primal_sols`
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_ip_primal_bound(state) == 2.0
    update_ip_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [3.0], 3.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.ip_primal_sols`
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    ###

    ### lp primal
    update_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols`
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_primal_bound(state) == 2.0
    update_lp_primal_sol!(
        state, PrimalSolution(form, [getid(var)], [3.0], 3.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.lp_primal_sols`
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    ###

    ### lp dual
    update_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols`
    for sol in get_lp_dual_sols(state), (varid, val) in sol
        @test val == dualsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_dual_bound(state) == 1.0
    update_lp_dual_sol!(state, DualSolution(
        form, [getid(constr)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `dualsol` is NOT added to `state.lp_dual_sols`
    for sol in get_lp_dual_sols(state), (varid, val) in sol
        @test val == dualsol[varid]
    end
    ###

    ############################################################################################
    # MaxSense                                                                                 #
    ############################################################################################
    form = create_formulation!(
        Env(Coluna.Params()), Original(), obj_sense = Coluna.MathProg.MaxSense
    )
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    state = OptimizationState(
        form, max_length_ip_primal_sols = 2.0,
        max_length_lp_primal_sols = 2.0, max_length_lp_dual_sols = 2.0
    )
    primalsol = PrimalSolution(form, [getid(var)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY)
    dualsol = DualSolution(form, [getid(constr)], [2.0], 2.0, CB.UNKNOWN_FEASIBILITY)

    ### ip primal
    update_ip_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.ip_primal_sols`
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_ip_primal_bound(state) == 1.0
    update_ip_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.ip_primal_sols`
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    ###

    ### lp primal
    update_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols`
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_primal_bound(state) == 1.0
    update_lp_primal_sol!(
        state, PrimalSolution(form, [getid(var)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.lp_primal_sols`
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    ###

    ### lp dual
    update_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols`
    for sol in get_lp_dual_sols(state), (varid, val) in sol
        @test val == dualsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_dual_bound(state) == 2.0
    update_lp_dual_sol!(state, DualSolution(
        form, [getid(constr)], [3.0], 3.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `dualsol` is NOT added to `state.lp_dual_sols`
    for sol in get_lp_dual_sols(state), (varid, val) in sol
        @test val == dualsol[varid]
    end
    ###
end

function add_sol_tests()
    ############################################################################################
    # MinSense                                                                                 #
    ############################################################################################
    form = create_formulation!(Env(Coluna.Params()), Original())
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    state = OptimizationState(form)
    primalsol = PrimalSolution(form, [getid(var)], [2.0], 2.0, CB.UNKNOWN_FEASIBILITY)
    dualsol = DualSolution(form, [getid(constr)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY)

    ### ip primal
    add_ip_primal_sols!(
        state,
        PrimalSolution(form, [getid(var)], [3.0], 3.0, CB.UNKNOWN_FEASIBILITY),
        primalsol
    )
    # check that `primalsol` is added to `state.ip_primal_sols` and worst solution is removed
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_ip_primal_bound(state) == 2.0
    ###

    ### lp primal
    add_lp_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [3.0], 3.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test get_lp_primal_bound(state) == 3.0
    add_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols` and worst solution is removed
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_primal_bound(state) == 2.0
    ###

    ### lp dual
    add_lp_dual_sol!(state, DualSolution(
        form, [getid(constr)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test get_lp_dual_bound(state) == 0.0
    add_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols` and worst solution is removed
    for (varid, val) in get_best_lp_dual_sol(state)
        @test val == dualsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_dual_bound(state) == 1.0
    ###

    ############################################################################################
    # MaxSense                                                                                 #
    ############################################################################################
    form = create_formulation!(
        Env(Coluna.Params()), Original(), obj_sense = Coluna.MathProg.MaxSense
    )
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    state = OptimizationState(form)
    primalsol = PrimalSolution(form, [getid(var)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY)
    dualsol = DualSolution(form, [getid(constr)], [2.0], 2.0, CB.UNKNOWN_FEASIBILITY)

    ### ip primal
    add_ip_primal_sols!(
        state,
        PrimalSolution(form, [getid(var)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY),
        primalsol
    )
    # check that `primalsol` is added to `state.ip_primal_sols` and worst solution is removed
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_ip_primal_bound(state) == 1.0
    ###

    ### lp primal
    add_lp_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test get_lp_primal_bound(state) == 0.0
    add_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols` and worst solution is removed
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_primal_bound(state) == 1.0
    ###

    ### lp dual
    add_lp_dual_sol!(state, DualSolution(
        form, [getid(constr)], [3.0], 3.0, CB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test get_lp_dual_bound(state) == 3.0
    add_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols` and worst solution is removed
    for (varid, val) in get_best_lp_dual_sol(state)
        @test val == dualsol[varid]
    end
    # check that incumbent bound is updated
    @test get_lp_dual_bound(state) == 2.0
    ###
end

function set_sol_tests()
    ############################################################################################
    # MinSense                                                                                 #
    ############################################################################################
    form = create_formulation!(Env(Coluna.Params()), Original())
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    state = OptimizationState(
        form, ip_primal_bound = 3.0, lp_primal_bound = 3.0, lp_dual_bound = -1.0
    )
    primalsol = PrimalSolution(form, [getid(var)], [2.0], 2.0, CB.UNKNOWN_FEASIBILITY)
    dualsol = DualSolution(form, [getid(constr)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY)

    ### ip primal
    set_ip_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY
    ))
    set_ip_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.ip_primal_sols`
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is NOT updated
    @test get_ip_primal_bound(state) == 3.0
    ###

    ### lp primal
    set_lp_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY
    ))
    set_lp_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.lp_primal_sols`
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is NOT updated
    @test get_lp_primal_bound(state) == 3.0
    ###

    ### lp dual
    set_lp_dual_sol!(state, DualSolution(
        form, [getid(constr)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY
    ))
    set_lp_dual_sol!(state, dualsol)
    # check that only the solution which was set last is in `state.lp_dual_sols`
    for sol in get_lp_dual_sols(state), (varid, val) in sol
        @test val == dualsol[varid]
    end
    # check that incumbent bound is NOT updated
    @test get_lp_dual_bound(state) == -1.0
    ###

    ############################################################################################
    # MaxSense                                                                                 #
    ############################################################################################
    form = create_formulation!(
        Env(Coluna.Params()), Original(), obj_sense = Coluna.MathProg.MaxSense
    )
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    state = OptimizationState(
        form, ip_primal_bound = -1.0, lp_primal_bound = -1.0, lp_dual_bound = 3.0
    )
    primalsol = PrimalSolution(form, [getid(var)], [0.0], 0.0, CB.UNKNOWN_FEASIBILITY)
    dualsol = DualSolution(form, [getid(constr)], [2.0], 2.0, CB.UNKNOWN_FEASIBILITY)

    ### ip primal
    set_ip_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY
    ))
    set_ip_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.ip_primal_sols`
    for sol in get_ip_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is NOT updated
    @test get_ip_primal_bound(state) == -1.0
    ###

    ### lp primal
    set_lp_primal_sol!(state, PrimalSolution(
        form, [getid(var)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY
    ))
    set_lp_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.lp_primal_sols`
    for sol in get_lp_primal_sols(state), (varid, val) in sol
        @test val == primalsol[varid]
    end
    # check that incumbent bound is NOT updated
    @test get_lp_primal_bound(state) == -1.0
    ###

    ### lp dual
    set_lp_dual_sol!(state, DualSolution(
        form, [getid(constr)], [1.0], 1.0, CB.UNKNOWN_FEASIBILITY
    ))
    set_lp_dual_sol!(state, dualsol)
    # check that only the solution which was set last is in `state.lp_dual_sols`
    for sol in get_lp_dual_sols(state), (varid, val) in sol
        @test val == dualsol[varid]
    end
    # check that incumbent bound is NOT updated
    @test get_lp_dual_bound(state) == 3.0
    ###
end
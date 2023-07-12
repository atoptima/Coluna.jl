function formulation_for_optimizationstate(sense = Coluna.MathProg.MinSense)
    form = ClMP.create_formulation!(Env{ClMP.VarId}(Coluna.Params()), ClMP.Original(), obj_sense = sense)
    var = ClMP.setvar!(form, "var1", ClMP.OriginalVar)
    constr = ClMP.setconstr!(form, "constr1", ClMP.OriginalConstr)
    return form, var, constr
end

function update_solution_with_min_objective()
    form, var, constr = formulation_for_optimizationstate()
    state = ClA.OptimizationState(
        form, max_length_ip_primal_sols = 2.0,
        max_length_lp_primal_sols = 2.0, max_length_lp_dual_sols = 2.0
    )
    primalsol = ClMP.PrimalSolution(form, [ClMP.getid(var)], [2.0], 2.0, ClB.UNKNOWN_FEASIBILITY)
    dualsol = ClMP.DualSolution(form, [ClMP.getid(constr)], [1.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 1.0, ClB.UNKNOWN_FEASIBILITY)

    ### ip primal
    ClA.update_ip_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.ip_primal_sols`
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_ip_primal_bound(state) == 2.0
    ClA.update_ip_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [3.0], 3.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.ip_primal_sols`
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    ###

    ### lp primal
    ClA.update_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols`
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_lp_primal_bound(state) == 2.0
    ClA.update_lp_primal_sol!(
        state, ClMP.PrimalSolution(form, [ClMP.getid(var)], [3.0], 3.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.lp_primal_sols`
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    ###

    ### lp dual
    ClA.update_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols`
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    # check that incumbent bound is updated
    @test ClA.get_lp_dual_bound(state) == 1.0
    ClA.update_lp_dual_sol!(state, ClMP.DualSolution(
        form, [ClMP.getid(constr)], [0.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 0.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `dualsol` is NOT added to `state.lp_dual_sols`
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    ###
end
register!(unit_tests, "optimization_state", update_solution_with_min_objective)

function update_solution_with_max_objective()
    form, var, constr = formulation_for_optimizationstate(ClMP.MaxSense)
    state = ClA.OptimizationState(
        form, max_length_ip_primal_sols = 2.0,
        max_length_lp_primal_sols = 2.0, max_length_lp_dual_sols = 2.0
    )
    primalsol = ClMP.PrimalSolution(form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY)
    dualsol = ClMP.DualSolution(form, [ClMP.getid(constr)], [2.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 2.0, ClB.UNKNOWN_FEASIBILITY)

    ### ip primal
    ClA.update_ip_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.ip_primal_sols`
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_ip_primal_bound(state) == 1.0
    ClA.update_ip_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.ip_primal_sols`
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    ###

    ### lp primal
    ClA.update_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols`
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_lp_primal_bound(state) == 1.0
    ClA.update_lp_primal_sol!(
        state, ClMP.PrimalSolution(form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `primalsol` is NOT added to `state.lp_primal_sols`
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    ###

    ### lp dual
    ClA.update_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols`
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    # check that incumbent bound is updated
    @test ClA.get_lp_dual_bound(state) == 2.0
    ClA.update_lp_dual_sol!(state, ClMP.DualSolution(
        form, [ClMP.getid(constr)], [3.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 3.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that solution worse than `dualsol` is NOT added to `state.lp_dual_sols`
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    ###
end
register!(unit_tests, "optimization_state", update_solution_with_max_objective)

function add_solution_with_min_objective()
    form, var, constr = formulation_for_optimizationstate()
    state = ClA.OptimizationState(form)
    primalsol = ClMP.PrimalSolution(form, [ClMP.getid(var)], [2.0], 2.0, ClB.UNKNOWN_FEASIBILITY)
    dualsol = ClMP.DualSolution(form, [ClMP.getid(constr)], [1.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 1.0, ClB.UNKNOWN_FEASIBILITY)

    ### ip primal
    ClA.add_ip_primal_sols!(
        state,
        ClMP.PrimalSolution(form, [ClMP.getid(var)], [3.0], 3.0, ClB.UNKNOWN_FEASIBILITY),
        primalsol
    )
    # check that `primalsol` is added to `state.ip_primal_sols` and worst solution is removed
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_ip_primal_bound(state) == 2.0
    ###

    ### lp primal
    ClA.add_lp_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [3.0], 3.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test ClA.get_lp_primal_bound(state) == 3.0
    ClA.add_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols` and worst solution is removed
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_lp_primal_bound(state) == 2.0
    ###

    ### lp dual
    ClA.add_lp_dual_sol!(state, ClMP.DualSolution(
        form, [ClMP.getid(constr)], [0.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 0.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test ClA.get_lp_dual_bound(state) == 0.0
    ClA.add_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols` and worst solution is removed
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    # check that incumbent bound is updated
    @test ClA.get_lp_dual_bound(state) == 1.0
    ###
end
register!(unit_tests, "optimization_state", add_solution_with_min_objective)

function add_solution_with_max_objective()
    form, var, constr = formulation_for_optimizationstate(ClMP.MaxSense)
    state = ClA.OptimizationState(form)
    primalsol = ClMP.PrimalSolution(form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY)
    dualsol = ClMP.DualSolution(form, [ClMP.getid(constr)], [2.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 2.0, ClB.UNKNOWN_FEASIBILITY)

    ### ip primal
    ClA.add_ip_primal_sols!(
        state,
        ClMP.PrimalSolution(form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY),
        primalsol
    )
    # check that `primalsol` is added to `state.ip_primal_sols` and worst solution is removed
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_ip_primal_bound(state) == 1.0
    ###

    ### lp primal
    ClA.add_lp_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test ClA.get_lp_primal_bound(state) == 0.0
    ClA.add_lp_primal_sol!(state, primalsol)
    # check that `primalsol` is added to `state.lp_primal_sols` and worst solution is removed
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    # check that incumbent bound is updated
    @test ClA.get_lp_primal_bound(state) == 1.0
    ###

    ### lp dual
    ClA.add_lp_dual_sol!(state, ClMP.DualSolution(
        form, [ClMP.getid(constr)], [3.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 3.0, ClB.UNKNOWN_FEASIBILITY
    ))
    # check that incumbent bound is updated
    @test ClA.get_lp_dual_bound(state) == 3.0
    ClA.add_lp_dual_sol!(state, dualsol)
    # check that `dualsol` is added to `state.lp_dual_sols` and worst solution is removed
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    # check that incumbent bound is updated
    @test ClA.get_lp_dual_bound(state) == 2.0
    ###
end
register!(unit_tests, "optimization_state", add_solution_with_max_objective)

function set_solution_with_min_objective()
    form, var, constr = formulation_for_optimizationstate()
    state = ClA.OptimizationState(
        form, ip_primal_bound = 3.0, lp_primal_bound = 3.0, lp_dual_bound = -1.0
    )
    primalsol = ClMP.PrimalSolution(form, [ClMP.getid(var)], [2.0], 2.0, ClB.UNKNOWN_FEASIBILITY)
    dualsol = ClMP.DualSolution(form, [ClMP.getid(constr)], [0.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 0.0, ClB.UNKNOWN_FEASIBILITY)

    ### ip primal
    ClA.set_ip_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY
    ))
    ClA.set_ip_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.ip_primal_sols`
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    # check that incumbent bound is NOT updated
    @test ClA.get_ip_primal_bound(state) == 3.0
    ###

    ### lp primal
    ClA.set_lp_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY
    ))
    ClA.set_lp_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.lp_primal_sols`
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    # check that incumbent bound is NOT updated
    @test ClA.get_lp_primal_bound(state) == 3.0
    ###

    ### lp dual
    ClA.set_lp_dual_sol!(state, ClMP.DualSolution(
        form, [ClMP.getid(constr)], [1.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 1.0, ClB.UNKNOWN_FEASIBILITY
    ))
    ClA.set_lp_dual_sol!(state, dualsol)
    # check that only the solution which was set last is in `state.lp_dual_sols`
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    # check that incumbent bound is NOT updated
    @test ClA.get_lp_dual_bound(state) == -1.0
    ###
end
register!(unit_tests, "optimization_state", set_solution_with_min_objective)

function set_solution_with_max_objective()
    form, var, constr = formulation_for_optimizationstate(ClMP.MaxSense)
    state = ClA.OptimizationState(
        form, ip_primal_bound = -1.0, lp_primal_bound = -1.0, lp_dual_bound = 3.0
    )
    primalsol = ClMP.PrimalSolution(form, [ClMP.getid(var)], [0.0], 0.0, ClB.UNKNOWN_FEASIBILITY)
    dualsol = ClMP.DualSolution(form, [ClMP.getid(constr)], [2.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 2.0, ClB.UNKNOWN_FEASIBILITY)

    ### ip primal
    ClA.set_ip_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY
    ))
    ClA.set_ip_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.ip_primal_sols`
    @test length(ClA.get_ip_primal_sols(state)) == 1
    @test ClA.get_ip_primal_sols(state)[1] == primalsol
    # check that incumbent bound is NOT updated
    @test ClA.get_ip_primal_bound(state) == -1.0
    ###

    ### lp primal
    ClA.set_lp_primal_sol!(state, ClMP.PrimalSolution(
        form, [ClMP.getid(var)], [1.0], 1.0, ClB.UNKNOWN_FEASIBILITY
    ))
    ClA.set_lp_primal_sol!(state, primalsol)
    # check that only the solution which was set last is in `state.lp_primal_sols`
    @test length(ClA.get_lp_primal_sols(state)) == 1
    @test ClA.get_lp_primal_sols(state)[1] == primalsol
    # check that incumbent bound is NOT updated
    @test ClA.get_lp_primal_bound(state) == -1.0
    ###

    ### lp dual
    ClA.set_lp_dual_sol!(state, ClMP.DualSolution(
        form, [ClMP.getid(constr)], [1.0], ClMP.VarId[], Float64[], ClMP.ActiveBound[], 1.0, ClB.UNKNOWN_FEASIBILITY
    ))
    ClA.set_lp_dual_sol!(state, dualsol)
    # check that only the solution which was set last is in `state.lp_dual_sols`
    @test length(ClA.get_lp_dual_sols(state)) == 1
    @test ClA.get_lp_dual_sols(state)[1] == dualsol
    # check that incumbent bound is NOT updated
    @test ClA.get_lp_dual_bound(state) == 3.0
end
register!(unit_tests, "optimization_state", set_solution_with_max_objective)
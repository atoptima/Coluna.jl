function incumbents_unit_tests()
    incumbents_getters_and_setters_unit_tests()
end

function incumbents_getters_and_setters_unit_tests()
    inc = ClF.Incumbents(ClF.MinSense)
    max_inc = ClF.Incumbents(ClF.MaxSense)

    @test ClF.getsense(inc) == ClF.MinSense
    @test ClF.getsense(max_inc) == ClF.MaxSense

    f = ClF.Formulation{ClF.Original}(ClF.Counter(), obj_sense = ClF.MinSense)

    varids = [ClF.Id{ClF.Variable}(ClF.OriginalVar, i, 1) for i in 1:5]
    constrids = [ClF.Id{ClF.Constraint}(ClF.OriginalConstr, i, 1) for i in 1:5]

    bound = ClF.PrimalBound{ClF.MinSense}(8.1)
    solution = Dict(varids[1] => 2.1, varids[3] => 1.4)
    lp_primal_sol = ClF.PrimalSolution(f, solution, bound)

    @test ClF.update_lp_primal_sol!(inc, lp_primal_sol)
    @test ClF.get_lp_primal_sol(inc) == lp_primal_sol
    @test ClF.get_lp_primal_bound(inc) == 8.1

    bound = ClF.PrimalBound{ClF.MinSense}(9.6)
    solution = Dict(varids[2] => 3.5)
    lp_primal_sol = ClF.PrimalSolution(f, solution, bound)
    @test !ClF.update_lp_primal_sol!(inc, lp_primal_sol)
    @test ClF.get_lp_primal_bound(inc) == 8.1

    bound = ClF.PrimalBound{ClF.MinSense}(12.0)
    solution = Dict(varids[3] => 2.0, varids[4] => 1.0)
    ip_primal_sol = ClF.PrimalSolution(f, solution, bound)
    @test ClF.update_ip_primal_sol!(inc, ip_primal_sol)
    @test ClF.get_ip_primal_sol(inc) == ip_primal_sol
    @test ClF.get_ip_primal_bound(inc) == 12.0

    bound = ClF.DualBound{ClF.MinSense}(1.1)
    solution = Dict(constrids[3] => 0.1, constrids[5] => 0.9)
    lp_dual_sol = ClF.DualSolution(f, solution, bound)
    @test ClF.update_lp_dual_sol!(inc, lp_dual_sol)
    @test ClF.get_lp_dual_sol(inc) == lp_dual_sol
    @test ClF.get_lp_dual_bound(inc) == 1.1

    bound = ClF.DualBound{ClF.MinSense}(2.0)
    @test ClF.update_ip_dual_bound!(inc, bound)
    @test ClF.get_ip_dual_bound(inc) == 2.0

    @test ClF.ip_gap(inc) == (12.0 - 2.0) / 2.0
    @test ClF.lp_gap(inc) == (8.1 - 1.1) / 1.1
end

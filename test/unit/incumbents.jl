function incumbents_unit_tests()
    incumbents_getters_and_setters_unit_tests()
end

function incumbents_getters_and_setters_unit_tests()
    inc = CL.Incumbents(CL.MinSense)
    max_inc = CL.Incumbents(CL.MaxSense)

    @test CL.getsense(inc) == CL.MinSense
    @test CL.getsense(max_inc) == CL.MaxSense

    f = CL.Formulation{CL.Original}(CL.Counter(), obj_sense = CL.MinSense)

    var_ids = [CL.Id{CL.Variable}(i, 1) for i in 1:5]
    constr_ids = [CL.Id{CL.Constraint}(i, 1) for i in 1:5]

    bound = CL.PrimalBound{CL.MinSense}(8.1)
    solution = Dict(var_ids[1] => 2.1, var_ids[3] => 1.4)
    lp_primal_sol = CL.PrimalSolution(f, bound, solution)

    @test CL.set_lp_primal_sol!(inc, lp_primal_sol)
    @test CL.get_lp_primal_sol(inc) == lp_primal_sol
    @test CL.get_lp_primal_bound(inc) == 8.1

    bound = CL.PrimalBound{CL.MinSense}(9.6)
    solution = Dict(var_ids[2] => 3.5)
    lp_primal_sol = CL.PrimalSolution(f, bound, solution)
    @test !CL.set_lp_primal_sol!(inc, lp_primal_sol)
    @test CL.get_lp_primal_bound(inc) == 8.1

    bound = CL.PrimalBound{CL.MinSense}(12.0)
    solution = Dict(var_ids[3] => 2.0, var_ids[4] => 1.0)
    ip_primal_sol = CL.PrimalSolution(f, bound, solution)
    @test CL.set_ip_primal_sol!(inc, ip_primal_sol)
    @test CL.get_ip_primal_sol(inc) == ip_primal_sol
    @test CL.get_ip_primal_bound(inc) == 12.0

    bound = CL.DualBound{CL.MinSense}(1.1)
    solution = Dict(constr_ids[3] => 0.1, constr_ids[5] => 0.9)
    lp_dual_sol = CL.DualSolution(f, bound, solution)
    @test CL.set_lp_dual_sol!(inc, lp_dual_sol)
    @test CL.get_lp_dual_sol(inc) == lp_dual_sol
    @test CL.get_lp_dual_bound(inc) == 1.1

    bound = CL.DualBound{CL.MinSense}(2.0)
    @test CL.set_ip_dual_bound!(inc, bound)
    @test CL.get_ip_dual_bound(inc) == 2.0

    @test CL.ip_relativegap(inc) == (12.0 - 2.0) / 2.0
    @test CL.lp_relativegap(inc) == (8.1 - 1.1) / 1.1
end

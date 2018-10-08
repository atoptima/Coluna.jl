function alg_primal_heuristic_node_unit_tests()

    alg_primal_heuristic_node_tests()
    setup_primal_heur_tests()
    setdown_primal_heur_tests()
    alg_primal_heur_restricted_master_tests()
    run_restricted_master_heur_tests()    

end

function alg_primal_heuristic_node_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToPrimalHeurInNode(extended_problem)
    s_and_b = alg.sols_and_bounds
    @test s_and_b.alg_inc_ip_primal_bound == Inf
    @test s_and_b.alg_inc_lp_primal_bound == Inf
    @test s_and_b.alg_inc_ip_dual_bound == -Inf
    @test s_and_b.alg_inc_lp_dual_bound == -Inf
    @test s_and_b.alg_inc_lp_primal_sol_map == Dict{CL.Variable, Float64}()
    @test s_and_b.alg_inc_ip_primal_sol_map == Dict{CL.Variable, Float64}()
    @test s_and_b.alg_inc_lp_dual_sol_map == Dict{CL.Constraint, Float64}()
    @test s_and_b.is_alg_inc_ip_primal_bound_updated == false
end

function setup_primal_heur_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToPrimalHeurInNode(extended_problem)
    @test CL.setup(alg) == false
end

function setdown_primal_heur_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToPrimalHeurInNode(extended_problem)
    @test CL.setdown(alg) == false
end

function alg_primal_heur_restricted_master_tests()
    extended_problem = create_extended_problem()
    alg = CL.AlgToPrimalHeurByRestrictedMip(extended_problem)
    s_and_b = alg.sols_and_bounds
    @test s_and_b.alg_inc_ip_primal_bound == Inf
    @test s_and_b.alg_inc_lp_primal_bound == Inf
    @test s_and_b.alg_inc_ip_dual_bound == -Inf
    @test s_and_b.alg_inc_lp_dual_bound == -Inf
    @test s_and_b.alg_inc_lp_primal_sol_map == Dict{CL.Variable, Float64}()
    @test s_and_b.alg_inc_ip_primal_sol_map == Dict{CL.Variable, Float64}()
    @test s_and_b.alg_inc_lp_dual_sol_map == Dict{CL.Constraint, Float64}()
    @test s_and_b.is_alg_inc_ip_primal_bound_updated == false
end

function run_restricted_master_heur_tests()
    extended_problem = create_cg_extended_problem()
    CL.optimize(extended_problem)
    @test extended_problem.primal_inc_bound == 2.0
    @test extended_problem.dual_inc_bound == 2.0
    alg = CL.AlgToPrimalHeurByRestrictedMip(extended_problem)
    CL.run(alg)
end

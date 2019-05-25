function build_master_moi_optimizer()
    return CL.MoiOptimizer(with_optimizer(GLPK.Optimizer)())
end

function build_sp_moi_optimizer()
    return CL.MoiOptimizer(with_optimizer(GLPK.Optimizer)())
end

function pricing_callback_tests()

    @testset "GAP with ad-hoc pricing callback " begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.with_optimizer(Coluna.Optimizer)

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        BD.assignsolver(dec, build_master_moi_optimizer)
        BD.assignsolver(dec[1:2], build_sp_moi_optimizer)
        @test BD.getoptimizerbuilder(dec) == build_master_moi_optimizer
        @test BD.getoptimizerbuilder(dec[1]) == build_sp_moi_optimizer
        @test BD.getoptimizerbuilder(dec[2]) == build_sp_moi_optimizer

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

end
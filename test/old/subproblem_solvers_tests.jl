function subproblem_solvers_test()
    @testset "play gap with lazy cuts" begin
        data = ClD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm(max_nb_cut_rounds = 1000)),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)
        subproblems = getsubproblems(dec)

        specify!(subproblems[1], lower_multiplicity=0, solver=JuMP.optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60 * 1_100, "msg_lev" => GLPK.GLP_MSG_OFF))
        specify!(subproblems[2], lower_multiplicity=0, solver=JuMP.optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60 * 2_200))
        
        optimize!(model)
        @test JuMP.objective_value(model) ≈ 75.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
    end
end
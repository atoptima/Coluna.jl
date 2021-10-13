function optimizer_with_attributes_test()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")


        println(JuMP.optimizer_with_attributes(GLPK.Optimizer))
        println(GLPK.Optimizer)
        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm(
                branchingtreefile = "playgap.dot"
            )),
            "default_optimizer" => JuMP.optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60 * 1_100, "msg_lev" => GLPK.GLP_MSG_OFF)
        )
        
        println(coluna)
        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        BD.objectiveprimalbound!(model, 100)
        BD.objectivedualbound!(model, 0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 75.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
        @test MOI.get(model, MOI.NumberOfVariables()) == length(x)
        @test MOI.get(model, MOI.SolverName()) == "Coluna"
    end
end
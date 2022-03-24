@testset "Lot Sizing" begin
    @testset "single mode multi items lot sizing" begin
        data = ClD.SingleModeMultiItemsLotSizing.data("lotSizing-3-20-2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(
                solver = ClA.BendersCutGeneration()
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = ClD.SingleModeMultiItemsLotSizing.model(data, coluna)
        JuMP.optimize!(problem)
        @test objective_value(problem) ≈ 600
    end

    @testset "capacitated lot sizing" begin
        data = ClD.CapacitatedLotSizing.readData("testSmall")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, y, s, dec = ClD.CapacitatedLotSizing.model(data, coluna)
        JuMP.optimize!(model)

        @test JuMP.termination_status(model) == MOI.OPTIMAL
    end
end
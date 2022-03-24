@testset "Cutting Stock" begin
    @testset "toy instance" begin
        data = ClD.CuttingStock.data("randomInstances/inst10-10")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = ClD.CuttingStock.model(data, coluna)
        JuMP.optimize!(problem)
        @test objective_value(problem) ≈ 4
    end
end

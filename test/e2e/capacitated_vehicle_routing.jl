@testset "Capacitated Vehicle Routing" begin
    @testset "toy instance" begin
        data = ClD.CapacitatedVehicleRouting.data("A-n16-k3.vrp")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm(
                maxnumnodes = 10000,
                branchingtreefile = "cvrp.dot"
            )),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = ClD.CapacitatedVehicleRouting.model(data, coluna)
        JuMP.optimize!(model)
        @test objective_value(model) ≈ 504
    end
end

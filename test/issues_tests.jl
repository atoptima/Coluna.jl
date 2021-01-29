
function test_issues_fixed()
    # Issue 425
    @testset "#425" begin
        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.SolveIpForm()),
            "default_optimizer" => GLPK.Optimizer
        )

        model = BlockModel(coluna, direct_model = true)
        @variable(model, x)
        @constraint(model, x <= 1)
        @objective(model, Max, x)

        optimize!(model)
        @test JuMP.objective_value(model) == 1.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
    end
end

test_issues_fixed()
# Issue #425
# When the user does not provide decomposition, Coluna should optimize the
# original formulation.
function solve_with_no_decomposition()
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

# Test that empty! empties the Problem
function test_model_empty()
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

    empty!(model)
    @variable(model, x)
    @constraint(model, x <= 2)
    @objective(model, Max, x)

    optimize!(model)
    @test JuMP.objective_value(model) == 2.0
    @test JuMP.termination_status(model) == MOI.OPTIMAL
end


function test_issues_fixed()
    @testset "no_decomposition" begin
        solve_with_no_decomposition()
    end

    @testset "moi_empty" begin
        test_model_empty()
    end
end

test_issues_fixed()
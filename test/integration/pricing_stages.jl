@testset "Pricing stages" begin
    colgenstages = Coluna.Algorithm.ColumnGeneration[]
    for stage in 1:2
        push!(colgenstages, Coluna.Algorithm.ColumnGeneration(
            pricing_prob_solve_alg = Coluna.Algorithm.SolveIpForm(optimizer_id = stage)
        ))
    end
    colcutgen = Coluna.Algorithm.ColCutGenConquer(
        stages = colgenstages,
        primal_heuristics = [],
    )
    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(
            solver = Coluna.Algorithm.TreeSearchAlgorithm(
                conqueralg = colcutgen
            )
        ),
        "default_optimizer" => GLPK.Optimizer
    )
    @axis(sp, [1])
    model = BlockModel(coluna)
    @variable(model, x[i in 1:6] >= 0, Int)
    c = [3, 3, 3, 1, 1, 1]
    @objective(model, Min, sum(c[i] * x[i] for i in 1:6))
    A = [1 0 1 1 0 0; 1 1 0 0 1 0; 0 1 1 0 0 1]
    @constraint(model, cov[i in 1:3], sum(x[j] for j in 1:6 if A[i, j] == 1) >= 1)

    @dantzig_wolfe_decomposition(model, dec, sp)

    function pricing_callback(cbdata, stage)
        @show stage
        n = (stage == 2) ? 3 : 6
        rcosts = [BlockDecomposition.callback_reduced_cost(cbdata, x[i]) for i in 1:n]
        @show rcosts
        bestrc, i = findmin(rcosts)
        solvars = [x[i]]
        solvals = [1.0]
        println("Priced x[$i]")
        MOI.submit(model, BlockDecomposition.PricingSolution(cbdata), bestrc, solvars, solvals)
        MOI.submit(
            model, BlockDecomposition.PricingDualBound(cbdata), (stage == 2) ? -Inf : bestrc
        )
    end

    master = BlockDecomposition.getmaster(dec)
    subproblems = BlockDecomposition.getsubproblems(dec)
    subproblemrepresentative.(x, Ref(subproblems))
    specify!(
        subproblems[1], lower_multiplicity = 0, upper_multiplicity = 4,
        solver = [cbdata -> pricing_callback(cbdata, stage) for stage in 1:2]
    )

    JuMP.optimize!(model)
    @test objective_value(model) == 3.0
end

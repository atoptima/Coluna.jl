@testset "Old - Disaggregated solution" begin
    I = 1:3
    @axis(BinsType, [1])

    w = [2, 5, 7]
    Q = 8

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(solver = ClA.ColumnGeneration()),
        "default_optimizer" => GLPK.Optimizer
    )

    model = BlockModel(coluna)

    @variable(model, x[k in BinsType, i in I], Bin)
    @variable(model, y[k in BinsType], Bin)

    @constraint(model, sp[i in I], sum(x[k, i] for k in BinsType) == 1)
    @constraint(model, ks[k in BinsType], sum(w[i] * x[k, i] for i in I) - y[k] * Q <= 0)

    @objective(model, Min, sum(y[k] for k in BinsType))

    @dantzig_wolfe_decomposition(model, dec, BinsType)
    subproblems = BlockDecomposition.getsubproblems(dec)
    specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = BD.length(I)) # we use at most 3 bins

    JuMP.optimize!(model)

    for k in BinsType
        bins = BD.getsolutions(model, k)
        for bin in bins
            @test BD.value(bin) == 1.0 # value of the master column variable
            @test BD.value(bin, x[k, 1]) == BD.value(bin, x[k, 2]) # x[1,1] and x[1,2] in the same bin
            @test BD.value(bin, x[k, 1]) != BD.value(bin, x[k, 3]) # only x[1,3] in its bin
            @test BD.value(bin, x[k, 2]) != BD.value(bin, x[k, 3]) # only x[1,3] in its bin
        end
    end
end

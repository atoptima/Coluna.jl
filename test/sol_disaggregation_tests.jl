coluna_backend(model::MOI.Utilities.CachingOptimizer) = coluna_backend(model.optimizer)
coluna_backend(b::MOI.Bridges.AbstractBridgeOptimizer) = coluna_backend(b.model)
coluna_backend(model) = model

function sol_disaggregation_tests()
    I = 1:20
    @axis(BinsType, [1])

    w = [10, 15, 27, 9, 12, 5, 17, 33, 4, 9, 34, 41, 26, 27, 16, 11, 19, 17, 19, 11]
    Q = 50

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(solver = Coluna.Algorithm.TreeSearchAlgorithm(
            branchingtreefile = "playgap.dot"
        )),
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
    specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = BD.length(I)) # we use at most 20 bins

    JuMP.optimize!(model)

    for k in BinsType
        bins = Coluna.getsolutions(coluna_backend(backend(model)), k)
        x_vals = zeros(BD.length(I))
        for bin in bins
            @show lambda_val = Coluna.value(bin) # value of the master column variable
            for i in I
                x_val = Coluna.value(bin, x[k, i].index) # coefficient of original var x[k, i] in the column bin
                if x_val != 0
                    x_vals[i] += x_val
                    @show x[k, i]
                end
            end
        end
        for i in I
            @test x_vals[i] == JuMP.value(x[k, i])
        end
    end
end

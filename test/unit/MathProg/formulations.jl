function max_nb_form_unit()
    coluna = optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => Coluna.Params(
            solver = Coluna.Algorithm.TreeSearchAlgorithm() # default BCP
        ),
        "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
    )
    @axis(M, 1:typemax(Int16)+1)
    model = BlockModel(coluna)
    @variable(model, x[m in M], Bin)
    @dantzig_wolfe_decomposition(model, decomposition, M)
    @test_throws ErrorException("Maximum number of formulations reached.") optimize!(model)
    return
end
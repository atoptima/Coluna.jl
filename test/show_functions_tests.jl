function show_functions_tests()
    data = CLD.GeneralizedAssignment.data("play2.txt")
    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
    )

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna, false)
    JuMP.optimize!(problem)
    @test_nowarn Base.show(problem.moi_backend.optimizer.inner.re_formulation.master.optimizer)
end

function show_functions_tests()
    data = CLD.GeneralizedAssignment.data("play2.txt")
    coluna = JuMP.with_optimizer(Coluna.Optimizer,
        default_optimizer = with_optimizer(GLPK.Optimizer)
    )
    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    JuMP.optimize!(problem)
    @test_nowarn Base.show(problem.moi_backend.optimizer.inner.re_formulation.master.optimizer)
end
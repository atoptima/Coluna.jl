function show_functions_tests()
    data = CLD.GeneralizedAssignment.data("play2.txt")
    coluna = JuMP.with_optimizer(CL.Optimizer,
        default_optimizer = with_optimizer(
        GLPK.Optimizer), params = CL.Params(
            ;global_strategy = ClA.GlobalStrategy(ClA.BnPnPreprocess(),
            ClA.NoBranching(), ClA.DepthFirst())
        )
    )
    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    JuMP.optimize!(problem)
    @test_nowarn Base.show(problem.moi_backend.optimizer.inner.re_formulation.master.optimizer)
end

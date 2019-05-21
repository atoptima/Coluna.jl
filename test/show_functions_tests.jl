function show_functions_tests()
    data = CLD.GeneralizedAssignment.data("play2.txt")
    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer))
    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    JuMP.optimize!(problem)
    @show fieldnames(typeof(problem.moi_backend))
    @test_nowarn CL._show_optimizer(problem.moi_backend.optimizer.inner.re_formulation.master.moi_optimizer)
end
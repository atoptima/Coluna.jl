function bound_callback_tests()
    data = CLD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(maxnumnodes = 2))
    )

    model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    JuMP.optimize!(model)
    # Branching constraint: x[1,1]>=1.0
    cbdata = MathProg.PricingCallbackData(model.moi_backend.inner.re_formulation.master)
    @test_broken BD.callback_lb(cbdata, x[1, 1]) == 1
    @test BD.callback_ub(cbdata, x[1, 1]) == 1
end
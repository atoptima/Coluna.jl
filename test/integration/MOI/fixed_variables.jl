# # We want to make sure that when put variables in the partial solution, these variables are 
# # removed from the subsolver and the solution returned contains the variables in the partial solution
# # variables and the cost of the partial solution.
function test_fixed_variables()
    env = CL.Env{ClMP.VarId}(CL.Params())

    # Create the following formulation:
    # min x1 + 2x2 + 3x3
    # st. x1 + 2x2 + 3x3 >= 16
    #     x1 >= 1
    #     x2 >= 2
    #     x3 >= 3

    form = ClMP.create_formulation!(env, ClMP.DwMaster())
    vars = Dict{String, ClMP.Variable}()
    for i in 1:3
        x = ClMP.setvar!(form, "x$i", ClMP.OriginalVar; cost = i, lb = i)
        vars["x$i"] = x
    end

    members = Dict{ClMP.VarId,Float64}(
        ClMP.getid(vars["x1"]) => 1,
        ClMP.getid(vars["x2"]) => 2,
        ClMP.getid(vars["x3"]) => 3
    )
    c = ClMP.setconstr!(form, "c", ClMP.OriginalConstr;
        rhs = 16, sense = ClMP.Greater, members = members
    )

    ClMP.push_optimizer!(form, CL._optimizerbuilder(MOI._instantiate_and_check(GLPK.Optimizer)))
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))

    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 16
    @test ClMP.getvalue(dual_sol) == 16
    @test ClMP.getcurrhs(form, c) == 16

    @test primal_sol[ClMP.getid(vars["x1"])] == 1
    @test primal_sol[ClMP.getid(vars["x2"])] == 2
    @test primal_sol[ClMP.getid(vars["x3"])] ≈ 3 + 2/3

    # min   x1' + 2x2' + 3x3'
    # st.   x1' + 2x2' + 3x3' >= 16 - 1 - 4 - 9 >= 2
    #       x1' >= 0
    #       x2' >= 0
    #       x3' >= 0

    ClMP.add_to_partial_solution!(form, vars["x1"], 1)
    ClMP.add_to_partial_solution!(form, vars["x2"], 2)
    ClMP.add_to_partial_solution!(form, vars["x3"], 3)

    # We perform propagation by hand (the preprocessing should do it)
    ClMP.setcurrhs!(form, c, 2.0)
    ClMP.setcurlb!(form, vars["x1"], 0.0)
    ClMP.setcurlb!(form, vars["x2"], 0.0)
    ClMP.setcurlb!(form, vars["x3"], 0.0)

    output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))
    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 16
    @test ClMP.getvalue(dual_sol) == 16
    @test ClMP.getcurrhs(form, c) == 2

    @test primal_sol[ClMP.getid(vars["x1"])] == 1
    @test primal_sol[ClMP.getid(vars["x2"])] == 2
    @test primal_sol[ClMP.getid(vars["x3"])] ≈ 3 + 2/3
end
register!(integration_tests, "MOI - fixed_variables", test_fixed_variables)
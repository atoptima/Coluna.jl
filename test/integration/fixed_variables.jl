# We want to make sure that when we fix variables, these variables are 
# removed from the subsolver and the solution returned contains the fixed
# variables and the cost of the fixed variables.

@testset "Integration - fixed variables" begin
    env = CL.Env{ClMP.VarId}(CL.Params())

    # Create the following formulation:
    # min x1 + 2x2 + 3x3
    # st. x1 >= 1
    #     x2 >= 2
    #     x3 >= 3

    form = ClMP.create_formulation!(env, ClMP.DwMaster())
    vars = Dict{String, ClMP.Variable}()
    for i in 1:3
        x = ClMP.setvar!(form, "x$i", ClMP.OriginalVar; cost = i, lb = i)
        vars["x$i"] = x
    end

    ClMP.push_optimizer!(form, CL._optimizerbuilder(MOI._instantiate_and_check(GLPK.Optimizer)))
    DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

    output = ClA.run!(ClA.SolveLpForm(get_dual_solution = true), env, form, ClA.OptimizationState(form))

    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 14
    @test ClMP.getvalue(dual_sol) == 14

    ClMP.fix!(form, vars["x1"], 2)

    output = ClA.run!(ClA.SolveLpForm(get_dual_solution = true), env, form, ClA.OptimizationState(form))
    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 15
    @test ClMP.getvalue(dual_sol) == 15

    ClMP.fix!(form, vars["x2"], 3)
    
    output = ClA.run!(ClA.SolveLpForm(get_dual_solution = true), env, form, ClA.OptimizationState(form))
    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 17
    @test ClMP.getvalue(dual_sol) == 17

    ClMP.fix!(form, vars["x3"], 4)

    output = ClA.run!(ClA.SolveLpForm(get_dual_solution = true), env, form, ClA.OptimizationState(form))
    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 20
    @test ClMP.getvalue(dual_sol) == 20

    ClMP.setcurlb!(form, vars["x3"], 3)
    output = ClA.run!(ClA.SolveLpForm(get_dual_solution = true), env, form, ClA.OptimizationState(form))
    primal_sol = ClA.get_best_lp_primal_sol(output)
    dual_sol = ClA.get_best_lp_dual_sol(output)
    @test ClMP.getvalue(primal_sol) == 17
    @test ClMP.getvalue(dual_sol) == 17
end
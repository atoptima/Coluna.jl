# # We want to make sure that when we fix variables, these variables are 
# # removed from the subsolver and the solution returned contains the fixed
# # variables and the cost of the fixed variables.
# function test_fixed_variables()
#     env = CL.Env{ClMP.VarId}(CL.Params())

#     # Create the following formulation:
#     # min x1 + 2x2 + 3x3
#     # st. x1 + 2x2 + 3x3 >= 16
#     #     x1 >= 1
#     #     x2 >= 2
#     #     x3 >= 3

#     form = ClMP.create_formulation!(env, ClMP.DwMaster())
#     vars = Dict{String, ClMP.Variable}()
#     for i in 1:3
#         x = ClMP.setvar!(form, "x$i", ClMP.OriginalVar; cost = i, lb = i)
#         vars["x$i"] = x
#     end

#     members = Dict{ClMP.VarId,Float64}(
#         ClMP.getid(vars["x1"]) => 1,
#         ClMP.getid(vars["x2"]) => 2,
#         ClMP.getid(vars["x3"]) => 3
#     )
#     c = ClMP.setconstr!(form, "c", ClMP.OriginalConstr;
#         rhs = 16, sense = ClMP.Greater, members = members
#     )

#     ClMP.push_optimizer!(form, CL._optimizerbuilder(MOI._instantiate_and_check(GLPK.Optimizer)))
#     DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

#     output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))

#     primal_sol = ClA.get_best_lp_primal_sol(output)
#     dual_sol = ClA.get_best_lp_dual_sol(output)
#     @test ClMP.getvalue(primal_sol) == 16
#     @test ClMP.getvalue(dual_sol) == 16
#     @test ClMP.getcurrhs(form, c) == 16

#     # min   x1 + 2x2 +  x3
#     # st.        2x2 + 3x3  >= 14
#     #       x1 == 2
#     #       x2 >= 2
#     #       x3 >= 3
#     ClMP.fix!(form, vars["x1"], 2)

#     output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))
#     primal_sol = ClA.get_best_lp_primal_sol(output)
#     dual_sol = ClA.get_best_lp_dual_sol(output)
#     @test ClMP.getvalue(primal_sol) == 16
#     @test ClMP.getvalue(dual_sol) == 16
#     @test ClMP.getcurrhs(form, c) == 14

#     # min   x1 + 2x2 +  x3
#     # st.               3x3  >= 8
#     #       x1 == 2
#     #       x2 == 3
#     #       x3 >= 3
#     ClMP.fix!(form, vars["x2"], 3)
    
#     output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))
#     primal_sol = ClA.get_best_lp_primal_sol(output)
#     dual_sol = ClA.get_best_lp_dual_sol(output)
#     @test ClMP.getvalue(primal_sol) == 17
#     @test ClMP.getvalue(dual_sol) == 17
#     @test ClMP.getcurrhs(form, c) == 8

#     # min   x1 + 2x2 +  x3
#     # st.                0  >=  -4
#     #       x1 == 2
#     #       x2 == 3
#     #       x3 == 4
#     ClMP.fix!(form, vars["x3"], 4)

#     output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))
#     primal_sol = ClA.get_best_lp_primal_sol(output)
#     dual_sol = ClA.get_best_lp_dual_sol(output)
#     @test ClMP.getvalue(primal_sol) == 20
#     @test ClMP.getvalue(dual_sol) == 20
#     @test ClMP.getcurrhs(form, c) == -4

#     #@test_warn ClMP.setcurlb!(form, vars["x3"], 0)

#     ClMP.unfix!(form, vars["x3"])

#     output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))
#     primal_sol = ClA.get_best_lp_primal_sol(output)
#     dual_sol = ClA.get_best_lp_dual_sol(output)

#     @test ClMP.getvalue(primal_sol) == 20
#     @test ClMP.getvalue(dual_sol) == 20
#     @test ClMP.getcurrhs(form, c) == 8

#     ClMP.setcurlb!(form, vars["x3"], 3)
#     ClMP.setcurub!(form, vars["x3"], Inf)
#     output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))
#     primal_sol = ClA.get_best_lp_primal_sol(output)
#     dual_sol = ClA.get_best_lp_dual_sol(output)

#     @test ClMP.getvalue(primal_sol) == 17
#     @test ClMP.getvalue(dual_sol) == 17
#     @test ClMP.getcurrhs(form, c) == 8
# end
# register!(integration_tests, "MOI - fixed_variables", test_fixed_variables)
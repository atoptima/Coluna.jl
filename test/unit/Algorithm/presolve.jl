# @testset "Algorithm - Presolve" begin
#     @testset "RemovalOfFixedVariables" begin
#         @test ClA._fix_var(0.99, 1.01, 0.1)
#         @test !ClA._fix_var(0.98, 1.1, 0.1)
#         @test ClA._fix_var(1.5, 1.5, 0.1)

#         @test_broken !ClA._infeasible_var(1.09, 0.91, 0.1)
#         @test ClA._infeasible_var(1.2, 0.9, 0.1)

#         # Create the following formulation:
#         # min x1 + 2x2 + 3x3
#         # st. x1 >= 1
#         #     x2 >= 2
#         #     x3 >= 3
#         #     x1 + 2x2 + 3x3 >= 10
#         env = CL.Env{ClMP.VarId}(CL.Params())
#         form = ClMP.create_formulation!(env, ClMP.DwMaster())
#         vars = Dict{String, ClMP.Variable}()
#         for i in 1:3
#             x = ClMP.setvar!(form, "x$i", ClMP.OriginalVar; cost = i, lb = i)
#             vars["x$i"] = x
#         end

#         members = Dict{ClMP.VarId,Float64}(
#             ClMP.getid(vars["x1"]) => 1,
#             ClMP.getid(vars["x2"]) => 2,
#             ClMP.getid(vars["x3"]) => 3
#         )
#         c = ClMP.setconstr!(form, "c", ClMP.OriginalConstr;
#             rhs = 10, sense = ClMP.Greater, members = members
#         )
#         DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

#         @test ClMP.getcurrhs(form, c) == 10
        
#         ClMP.setcurlb!(form, vars["x1"], 2)
#         ClMP.setcurub!(form, vars["x1"], 2)
#         @test ClMP.getcurrhs(form, c) == 10

#         ClA.treat!(form, ClA.RemovalOfFixedVariables(1e-6))

#         @test ClMP.getcurrhs(form, c) == 10 - 2

#         ClMP.setcurlb!(form, vars["x2"], 3)
#         ClMP.setcurub!(form, vars["x2"], 3)

#         ClA.treat!(form, ClA.RemovalOfFixedVariables(1e-6))

#         @test ClMP.getcurrhs(form, c) == 10 - 2 - 2*3

#         ClMP.unfix!(form, vars["x1"])
#         ClMP.setcurlb!(form, vars["x1"], 1)
#         ClA.treat!(form, ClA.RemovalOfFixedVariables(1e-6))
#         @test ClMP.getcurrhs(form, c) == 10 - 2*3
#         return
#     end
# end
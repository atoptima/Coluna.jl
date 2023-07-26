@testset "Algorithm - SolveLpForm/MOIinterface" begin
    @testset "getprimal & getdual - case 1" begin
        # Create the following formulation:
        # min x1 + 2x2 + 3x3
        # st. x1 + 2x2 + 3x3 >= 16
        #     x1 == 2
        #     x2 == 3
        #     x3 >= 3

        # Variable x1 and x2 are MOI.NONBASIC but get_dual (MOIinterface) was ignoring them.
        # As a result, the value of the dual solution was not correct.

        env = CL.Env{ClMP.VarId}(CL.Params())
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

        ClMP.setcurlb!(form, vars["x1"], 2)
        ClMP.setcurlb!(form, vars["x2"], 3)
        ClMP.setcurub!(form, vars["x1"], 2)
        ClMP.setcurub!(form, vars["x2"], 3)
        ClMP.push_optimizer!(form, CL._optimizerbuilder(MOI._instantiate_and_check(GLPK.Optimizer)))
        DynamicSparseArrays.closefillmode!(ClMP.getcoefmatrix(form))

        @test ClMP.getcurlb(form, vars["x1"]) == ClMP.getcurub(form, vars["x1"]) == 2
        @test ClMP.getcurlb(form, vars["x2"]) == ClMP.getcurub(form, vars["x2"]) == 3

        output = ClA.run!(ClA.SolveLpForm(get_dual_sol = true), env, form, ClA.OptimizationState(form))

        primal_sol = ClA.get_best_lp_primal_sol(output)
        dual_sol = ClA.get_best_lp_dual_sol(output)
        
        @test ClMP.getvalue(primal_sol) == 17
        @test ClMP.getvalue(dual_sol) == 17
    end
end
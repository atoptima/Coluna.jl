@testset "Integration - pricing callback" begin
    # Formulation with a given nb of variables. No constraint & no cost.
    function build_formulation(nb_variables)
        env = CL.Env{ClMP.VarId}(CL.Params())
        form = ClMP.create_formulation!(env, DwSp(nothing, 0, 1, ClMP.Continuous))
        vars = Dict(
            "x$i" => ClMP.setvar!(form, "x$i", ClMP.DwSpPricingVar) for i in 1:nb_variables
        )

        fake_model = JuMP.Model()
        @variable(fake_model, x[i in 1:nb_variables])
    
        for name in ["x$i" for i in 1:nb_variables] 
            CleverDicts.add_item(env.varids, ClMP.getid(vars[name]))
        end
        return env, form, vars, x
    end

    @testset "cb returns a dual bound" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            CL._submit_dual_bound(cbdata, 0.5)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        output = run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
        state = ClA.getoptstate(output)
        @test ClA.get_ip_primal_bound(state) == Inf
        @test ClA.get_ip_dual_bound(state) == 0.5
        @test ClA.getterminationstatus(state) == CL.OTHER_LIMIT
        @test isnothing(get_best_ip_primal_sol(state))
        @test isnothing(ClA.get_best_lp_primal_sol(state))
    end

    @testset "cb returns optimal solution" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            cost = -15.0
            variables = [x[1].index, x[3].index] 
            values = [1.0, 1.0]
            custom_data = nothing
            CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
            CL._submit_dual_bound(cbdata, cost)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        expected_primalsol = ClMP.PrimalSolution(
            form, 
            [ClMP.getid(vars["x1"]), ClMP.getid(vars["x3"])],
            [1.0, 1.0],
            -15.0,
            CL.FEASIBLE_SOL
        )

        output = run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
        state = ClA.getoptstate(output)
        @test ClA.get_ip_primal_bound(state) == -15.0
        @test ClA.get_ip_dual_bound(state) == -15.0
        @test ClA.getterminationstatus(state) == ClB.OPTIMAL
        @test get_best_ip_primal_sol(state) == expected_primalsol
        @test isnothing(ClA.get_best_lp_primal_sol(state))
    end

    @testset "cb returns heuristic solution" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata) 
            cost = -15.0
            variables = [x[1].index, x[3].index] 
            values = [1.0, 1.0]
            custom_data = nothing
            CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
            CL._submit_dual_bound(cbdata, -20)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        expected_primalsol = ClMP.PrimalSolution(
            form, 
            [ClMP.getid(vars["x1"]), ClMP.getid(vars["x3"])],
            [1.0, 1.0],
            -15.0,
            CL.FEASIBLE_SOL
        )

        output = run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
        state = ClA.getoptstate(output)
        @test ClA.get_ip_primal_bound(state) == -15.0
        @test ClA.get_ip_dual_bound(state) == -20.0
        @test ClA.getterminationstatus(state) == ClB.OTHER_LIMIT
        @test get_best_ip_primal_sol(state) == expected_primalsol
        @test isnothing(ClA.get_best_lp_primal_sol(state))
    end

    @testset "cb returns infinite dual bound (infeasible)" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            CL._submit_dual_bound(cbdata, Inf)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        output = run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
        output = run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
        state = ClA.getoptstate(output)
        @test ClA.get_ip_primal_bound(state) == Inf
        @test ClA.get_ip_dual_bound(state) == Inf
        @test ClA.getterminationstatus(state) == ClB.INFEASIBLE
        @test isnothing(get_best_ip_primal_sol(state))
        @test isnothing(ClA.get_best_lp_primal_sol(state))
    end

    @testset "cb returns -infinite dual bound (dual infeasible)" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            cost = -15.0
            variables = [x[1].index, x[3].index] 
            values = [1.0, 1.0]
            custom_data = nothing
            CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
            CL._submit_dual_bound(cbdata, -Inf)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        output = run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
        state = ClA.getoptstate(output)
        @test ClA.get_ip_primal_bound(state) == -15.0
        @test ClA.get_ip_dual_bound(state) == -Inf
        @test ClA.getterminationstatus(state) == ClB.DUAL_INFEASIBLE
        @test !isnothing(ClA.get_best_ip_primal_sol(state))
        @test isnothing(ClA.get_best_lp_primal_sol(state))
    end

    @testset "cb returns incorrect dual bound" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            cost = -15.0
            variables = [x[1].index, x[3].index] 
            values = [1.0, 1.0]
            custom_data = nothing
            CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
            CL._submit_dual_bound(cbdata, -10) # dual bound > primal bound !!!
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        @test_throws ClA.IncorrectPricingDualBound run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
    end

    @testset "cb returns solution but no dual bound" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            cost = -15.0
            variables = [x[1].index, x[3].index] 
            values = [1.0, 1.0]
            custom_data = nothing
            CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        @test_throws ClA.MissingPricingDualBound run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
    end

    @testset "cb set dual bound twice" begin
        env, form, vars, x = build_formulation(5)

        function callback(cbdata)
            CL._submit_dual_bound(cbdata, 1.0)
            CL._submit_dual_bound(cbdata, 2.0)
        end
        push!(form.optimizers, ClMP.UserOptimizer(callback))

        @test_throws ClA.MultiplePricingDualBounds run!(ClA.UserOptimize(), env, form, ClA.OptimizationInput(ClA.OptimizationState(form)))
    end
end
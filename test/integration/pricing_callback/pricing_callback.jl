
# Formulation with a given nb of variables. No constraint & no cost.
function build_formulation(nb_variables)
    env = CL.Env{ClMP.VarId}(CL.Params())
    form = ClMP.create_formulation!(env, ClMP.DwSp(nothing, nothing, nothing, ClMP.Continuous))
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

# Specs about pricing callbacks (we consider the case of a minimization problem):
# - Optimal primal <-> optimal dual (case 1)
# - Unbounded primal <-> infeasible dual (case 2)
# - Infeasible primal <-> unbounded dual (case 3)
# - Infeasible primal <-> infeasible dual (case 4)
# - heuristic solution (case 5)

function cb_returns_a_dual_bound()
    env, form, vars, x = build_formulation(5)

    function callback(cbdata)
        CL._submit_dual_bound(cbdata, 0.5)
    end
    push!(form.optimizers, ClMP.UserOptimizer(callback))

    state = ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
    @test ClA.get_ip_primal_bound(state) == Inf
    @test ClA.get_ip_dual_bound(state) == 0.5
    @test ClA.getterminationstatus(state) == CL.OTHER_LIMIT
    @test isnothing(ClA.get_best_ip_primal_sol(state))
    @test isnothing(ClA.get_best_lp_primal_sol(state))
end
register!(integration_tests, "pricing_callback", cb_returns_a_dual_bound)

function cb_returns_an_optimal_solution() # case 1
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

    state = ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
    @test ClA.get_ip_primal_bound(state) == -15.0
    @test ClA.get_ip_dual_bound(state) == -15.0
    @test ClA.getterminationstatus(state) == ClB.OPTIMAL
    @test ClA.get_best_ip_primal_sol(state) == expected_primalsol
    @test isnothing(ClA.get_best_lp_primal_sol(state))
end
register!(integration_tests, "pricing_callback", cb_returns_an_optimal_solution)

function cb_returns_heuristic_solution() # case 5
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

    state = ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
    @test ClA.get_ip_primal_bound(state) == -15.0
    @test ClA.get_ip_dual_bound(state) == -20.0
    @test ClA.getterminationstatus(state) == ClB.OTHER_LIMIT
    @test ClA.get_best_ip_primal_sol(state) == expected_primalsol
    @test isnothing(ClA.get_best_lp_primal_sol(state))
end
register!(integration_tests, "pricing_callback", cb_returns_heuristic_solution)

function cb_returns_heuristic_solution_2() # case 5
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

    state = ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
    @test ClA.get_ip_primal_bound(state) == -15.0
    @test ClA.get_ip_dual_bound(state) == -Inf
    @test ClA.getterminationstatus(state) == ClB.OTHER_LIMIT
    @test !isnothing(ClA.get_best_ip_primal_sol(state))
    @test isnothing(ClA.get_best_lp_primal_sol(state))
end
register!(integration_tests, "pricing_callback", cb_returns_heuristic_solution_2)

# cb returns infinite dual bound (primal infeasible)
function cb_returns_infinite_dual_bound() # case 4
    env, form, vars, x = build_formulation(5)

    function callback(cbdata)
        CL._submit_dual_bound(cbdata, Inf)
    end
    push!(form.optimizers, ClMP.UserOptimizer(callback))

    state = ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
    @test ClA.get_ip_primal_bound(state) === nothing
    @test ClA.get_ip_dual_bound(state) == Inf
    @test ClA.getterminationstatus(state) == ClB.INFEASIBLE
    @test isnothing(ClA.get_best_ip_primal_sol(state))
    @test isnothing(ClA.get_best_lp_primal_sol(state))
end
register!(integration_tests, "pricing_callback", cb_returns_infinite_dual_bound)

function cb_returns_unbounded_primal() # case 2
    env, form, vars, x = build_formulation(5)

    function callback(cbdata)
        cost = -Inf
        variables = Coluna.MathProg.VarId[] 
        values = Float64[]
        custom_data = nothing
        CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
        CL._submit_dual_bound(cbdata, nothing)
    end
    push!(form.optimizers, ClMP.UserOptimizer(callback))

    state = ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
    @test ClA.get_ip_primal_bound(state) == -Inf
    @test ClA.get_ip_dual_bound(state) === nothing
    @test ClA.getterminationstatus(state) == ClB.UNBOUNDED
    @test isnothing(ClA.get_best_lp_primal_sol(state))
end
register!(integration_tests, "pricing_callback", cb_returns_unbounded_primal)

function cb_returns_incorrect_dual_bound()
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

    @test_throws ClA.IncorrectPricingDualBound ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
end
register!(integration_tests, "pricing_callback", cb_returns_incorrect_dual_bound)

function cb_returns_solution_but_no_dual_bound()
    env, form, vars, x = build_formulation(5)

    function callback(cbdata)
        cost = -15.0
        variables = [x[1].index, x[3].index] 
        values = [1.0, 1.0]
        custom_data = nothing
        CL._submit_pricing_solution(env, cbdata, cost, variables, values, custom_data)
    end
    push!(form.optimizers, ClMP.UserOptimizer(callback))

    @test_throws ClA.MissingPricingDualBound ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
end
register!(integration_tests, "pricing_callback", cb_returns_solution_but_no_dual_bound)

function cb_set_dual_bound_twice()
    env, form, vars, x = build_formulation(5)

    function callback(cbdata)
        CL._submit_dual_bound(cbdata, 1.0)
        CL._submit_dual_bound(cbdata, 2.0)
    end
    push!(form.optimizers, ClMP.UserOptimizer(callback))

    @test_throws ClA.MultiplePricingDualBounds ClA.run!(ClA.UserOptimize(), env, form, ClA.OptimizationState(form))
end
register!(integration_tests, "pricing_callback", cb_set_dual_bound_twice)
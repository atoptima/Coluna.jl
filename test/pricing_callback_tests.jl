function pricing_callback_tests()
    @testset "GAP with ad-hoc single-stage pricing callback " begin
        pricing_callback_test(two_pricing_phases = false)
    end

    @testset "GAP with ad-hoc two-stage pricing callback " begin
        pricing_callback_test(two_pricing_phases = true)
    end
end

function pricing_callback_test(;two_pricing_phases::Bool)
    data = CLD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => CL.Params(
            solver = two_pricing_phases ? ClA.TreeSearchAlgorithm(
                conqueralg = ClA.ColCutGenConquer(
                        colgen = ClA.ColumnGeneration(initial_pricing_phase = 1)
                )
            ) : ClA.TreeSearchAlgorithm()
        )
    )

    model, x, dec = CLD.GeneralizedAssignment.model_without_knp_constraints(data, coluna)

    # Subproblem models are created once and for all
    # One model for each machine
    sp_models = Dict{Int, Any}()
    for m in data.machines
        sp = JuMP.Model(GLPK.Optimizer)
        @variable(sp, y[j in data.jobs], Bin)
        @variable(sp, lb_y[j in data.jobs] >= 0)
        @variable(sp, ub_y[j in data.jobs] >= 0)
        @variable(sp, max_card >= 0) # this sets the maximum solution cardinality for heuristic pricing
        @constraint(sp, card, sum(y[j] for j in data.jobs) <= max_card)
        @constraint(sp, knp, sum(data.weight[j,m]*y[j] for j in data.jobs) <= data.capacity[m])
        @constraint(sp, lbs[j in data.jobs], y[j] + lb_y[j] >= 0)
        @constraint(sp, ubs[j in data.jobs], y[j] - ub_y[j] <= 0)
        sp_models[m] = (sp, y, lb_y, ub_y, max_card)
    end
    nb_exact_calls = 0

    function my_pricing_callback(cbdata)
        machine_id = BD.callback_spid(cbdata, model)
        if cbdata.phase == 0
            nb_exact_calls += 1
        end

        sp, y, lb_y, ub_y, max_card = sp_models[machine_id]

        red_costs = [BD.callback_reduced_cost(cbdata, x[machine_id, j]) for j in data.jobs]

        # Update the model
        ## Bounds on subproblem variables
        for j in data.jobs
            JuMP.fix(lb_y[j], BD.callback_lb(cbdata, x[machine_id, j]), force = true)
            JuMP.fix(ub_y[j], BD.callback_ub(cbdata, x[machine_id, j]), force = true)
        end
        JuMP.fix(max_card, (cbdata.phase == 0) ? length(data.jobs) : 3, force = true)
        ## Objective function
        @objective(sp, Min, sum(red_costs[j]*y[j] for j in data.jobs))

        JuMP.optimize!(sp)

        # Retrieve the solution
        solcost = JuMP.objective_value(sp)
        solvars = JuMP.VariableRef[]
        solvarvals = Float64[]
        for j in data.jobs
            val = JuMP.value(y[j])
            if val ≈ 1
                push!(solvars, x[machine_id, j])
                push!(solvarvals, 1.0)
            end
        end

        # Submit the solution
        MOI.submit(
            model, BD.PricingSolution(cbdata), solcost, solvars, solvarvals
        )
        return
    end

    master = BD.getmaster(dec)
    subproblems = BD.getsubproblems(dec)

    BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_callback)

    JuMP.optimize!(model)
    # here, the number of calls may change due to numerical precision depending on the Julia
    # version. The values below are secure values that ensure that heristic pricing reduces
    # the number of exact pricing executions.
    @test (two_pricing_phases ? nb_exact_calls <= 25 : nb_exact_calls >= 30)
    @test JuMP.objective_value(model) ≈ 75.0
    @test JuMP.termination_status(model) == MOI.OPTIMAL
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
end

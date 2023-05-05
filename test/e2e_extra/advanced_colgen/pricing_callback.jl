function gap_with_pricing_callback_and_stages()
    data = ClD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "default_optimizer" => GLPK.Optimizer,
        "params" => CL.Params(
            solver = ClA.BranchCutAndPriceAlgorithm(
                colgen_stages_pricing_solvers = [3, 2]
            )
        )
    )

    model, x, dec = ClD.GeneralizedAssignment.model_without_knp_constraints(data, coluna)

    # Subproblem models are created once and for all
    # One model for each machine.
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
    function pricing_callback_stage2(cbdata)
        machine_id = BD.callback_spid(cbdata, model)
        _, _, _, _, max_card = sp_models[machine_id]
        JuMP.fix(max_card, 3, force = true)
        solcost, solvars, solvarvals = solve_pricing!(cbdata, machine_id)
        MOI.submit(
            model, BD.PricingSolution(cbdata), solcost, solvars, solvarvals
        )
        MOI.submit(model, BD.PricingDualBound(cbdata), -Inf)
    end

    function pricing_callback_stage1(cbdata)
        machine_id = BD.callback_spid(cbdata, model)
        _, _, _, _, max_card = sp_models[machine_id]
        JuMP.fix(max_card, length(data.jobs), force = true)
        nb_exact_calls += 1
        solcost, solvars, solvarvals = solve_pricing!(cbdata, machine_id)
        MOI.submit(
            model, BD.PricingSolution(cbdata), solcost, solvars, solvarvals
        )
        MOI.submit(model, BD.PricingDualBound(cbdata), solcost)
    end

    function solve_pricing!(cbdata, machine_id)
        sp, y, lb_y, ub_y, _ = sp_models[machine_id]
        red_costs = [BD.callback_reduced_cost(cbdata, x[machine_id, j]) for j in data.jobs]

        # Update the model
        ## Bounds on subproblem variables
        for j in data.jobs
            JuMP.fix(lb_y[j], BD.callback_lb(cbdata, x[machine_id, j]), force = true)
            JuMP.fix(ub_y[j], BD.callback_ub(cbdata, x[machine_id, j]), force = true)
        end

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
        return solcost, solvars, solvarvals
    end

    subproblems = BD.getsubproblems(dec)
    BD.specify!.(subproblems, lower_multiplicity = 0, solver = [GLPK.Optimizer, pricing_callback_stage2, pricing_callback_stage1])

    JuMP.optimize!(model)
    @test nb_exact_calls < 30   # WARNING: this test is necessary to properly test stage 2.
                                # Disabling stage 2 (uncommenting line 48) generates 40 exact
                                # calls, against 18 when it is enabled. These numbers may change
                                # a little bit with versions due to numerical errors.
    @test JuMP.objective_value(model) ≈ 75.0
    @test JuMP.termination_status(model) == MOI.OPTIMAL
    @test ClD.GeneralizedAssignment.print_and_check_sol(data, model, x)
end
register!(e2e_extra_tests, "pricing_callback", gap_with_pricing_callback_and_stages)
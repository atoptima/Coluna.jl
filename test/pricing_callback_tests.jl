function pricing_callback_tests()

    @testset "GAP with ad-hoc pricing callback " begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "default_optimizer" => GLPK.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
        )

        model, x, dec = CLD.GeneralizedAssignment.model_without_knp_constraints(data, coluna)

        function my_pricing_oracle(oracledata)
            machine_id = BD.oracle_spid(oracledata, model)

            costs = [BD.oracle_cost(oracledata, x[machine_id, j]) for j in data.jobs]
            lbs = [BD.oracle_lb(oracledata, x[machine_id, j]) for j in data.jobs]
            ubs =  [BD.oracle_ub(oracledata, x[machine_id, j]) for j in data.jobs]

            println("\e[43m")
            for j in data.jobs
                println("\t\t >> x[$machine_id, $j] = ", costs[j])
            end
            println("\e[00m")
            #test_costs = BD.oracle_cost.(oracledata, x[machine_id, :]) # TODO

            # Model to solve the knp subproblem
            sp = JuMP.Model(GLPK.Optimizer)
            @variable(sp, lbs[j] <= y[j in data.jobs] <= ubs[j])
            @objective(sp, Min, sum(costs[j] * y[j] for j in data.jobs))

            @constraint(sp, knp, 
                sum(data.weight[j,machine_id] * y[j]
                for j in data.jobs) <= data.capacity[machine_id]
            )

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
                model, BD.PricingSolution(oracledata), solcost, solvars, 
                solvarvals
            )
            print(oracledata.form, oracledata.result)
            return
        end

        master = BD.getmaster(dec)
        subproblems = BD.getsubproblems(dec)
        
        BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_oracle)

        JuMP.optimize!(model)
        @test JuMP.objective_value(model) ≈ 75.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    end

end

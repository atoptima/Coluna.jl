function pricing_callback_tests()

    @testset "GAP with ad-hoc pricing callback " begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "default_optimizer" => GLPK.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
        )

        problem, x, dec = CLD.GeneralizedAssignment.model_without_knp_constraints(data, coluna)

        function my_pricing_oracle(oracledata)
            println("Pricing callback called")

            machine = BD.oracle_spid(oracledata, problem)

            @show machine

            @show typeof(oracledata)
            form = oracledata.form
    
            #subproblem = CL.get_sp_axis_id(cbdata)

            println("\e[34m ******************** \e[00m")
            @show form
        

            vars = [v for (id,v) in Iterators.filter(
                v -> (CL.iscuractive(form,v.first) && CL.iscurexplicit(form,v.first) && CL.getduty(v.first) <= CL.DwSpPricingVar),
                CL.getvars(form)
            )]
            vars_job_id = Vector{Int}()
            for v in vars
                m = match(r"x\[\d+\,(\d)+\]", CL.getname(form, v))
                job_id = parse(Int, m.captures[1])
                push!(vars_job_id, job_id)
            end

            m = match(r"x\[(\d)+\,\d+\]", CL.getname(form, vars[1]))
            machine_id = parse(Int, m.captures[1])
            @show machine_id

            setup_var = [v for (id,v) in Iterators.filter(
                v -> (CL.iscuractive(form,v.first) && CL.iscurexplicit(form,v.first) && CL.getduty(v.first) <= CL.DwSpSetupVar),
                CL.getvars(form)
            )][1]
           
            m = JuMP.Model(GLPK.Optimizer)
            @variable(m, CL.getcurlb(form, vars[i]) <= xsp[i=1:length(vars)] <= CL.getcurub(form, vars[i]), Int)
            @objective(m, Min, sum(CL.getcurcost(form, vars[j]) * xsp[j] for j in 1:length(vars)))
            @constraint(m, knp, 
                sum(data.weight[j,machine_id] * xsp[j]
                for j in 1:length(vars)) <= data.capacity[machine_id]
            )
            optimize!(m)

            @show m
            println("\e[34m ~~~~~******************** \e[00m")

            #result = CL.OptimizationResult{CL.MinSense}()
            #result.primal_bound = CL.PrimalBound(form, JuMP.objective_value(m))
            solvars = Vector{JuMP.VariableRef}()
            solvarvals = Vector{Float64}()
            for i in 1:length(xsp)
                val = JuMP.value(xsp[i])
                if val > 0.000001  || val < - 0.000001 # todo use a tolerance
                    push!(solvars, x[machine_id, vars_job_id[i]])
                    push!(solvarvals, val)
                end
            end
            #push!(solvarids, CL.getid(setup_var))
            #push!(solvarvals, 1.0)
            #push!(result.primal_sols, CL.PrimalSolution(form, solvarids, solvarvals, result.primal_bound))
            #CL.setfeasibilitystatus!(result, CL.FEASIBLE)
            #CL.setterminationstatus!(result, CL.OPTIMAL)

            MOI.submit(problem, BD.PricingSolution(oracledata), solvars, solvarvals)
            return #result
        end

        master = BD.getmaster(dec)
        subproblems = BD.getsubproblems(dec)
        
        BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_oracle)

        JuMP.optimize!(problem)
        @test JuMP.objective_value(problem) ≈ 75.0
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

end

function pricing_callback_tests()

    @testset "GAP with ad-hoc pricing callback " begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "default_optimizer" => GLPK.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
        )

        function my_pricing_oracle(form::CL.Formulation)
            println("Pricing callback called")
            # machine_id = CL.getuid(form) - 1
            # vars = [v for (id,v) in Iterators.filter(
            #     v -> (CL.iscuractive(form,v.first) && CL.iscurexplicit(form,v.first) && CL.getduty(v.first) <= CL.DwSpPricingVar),
            #     CL.getvars(form)
            # )]
            # setup_var = [v for (id,v) in Iterators.filter(
            #     v -> (CL.iscuractive(form,v.first) && CL.iscurexplicit(form,v.first) && CL.getduty(v.first) <= CL.DwSpSetupVar),
            #     CL.getvars(form)
            # )][1]
           
            # m = JuMP.Model(GLPK.Optimizer)
            # @variable(m, CL.getcurlb(form, vars[i]) <= x[i=1:length(vars)] <= CL.getcurub(form, vars[i]), Int)
            # @objective(m, Min, sum(CL.getcurcost(form, vars[j]) * x[j] for j in 1:length(vars)))
            # @constraint(m, knp, 
            #     sum(data.weight[j,machine_id] * x[j]
            #     for j in 1:length(vars)) <= data.capacity[machine_id]
            # )
            # optimize!(m)
            # result = CL.OptimizationResult{CL.MinSense}()
            # result.primal_bound = CL.PrimalBound(form, JuMP.objective_value(m))
            # solvarids = Vector{CL.VarId}()
            # solvarvals = Vector{CL.Float64}()
            # for i in 1:length(x)
            #     val = JuMP.value(x[i])
            #     if val > 0.000001  || val < - 0.000001 # todo use a tolerance
            #         push!(solvarids, CL.getid(vars[i]))
            #         push!(solvarvals, val)
            #     end
            # end
            # push!(solvarids, CL.getid(setup_var))
            # push!(solvarvals, 1.0)
            # push!(result.primal_sols, CL.PrimalSolution(form, solvarids, solvarvals, result.primal_bound))
            # CL.setfeasibilitystatus!(result, CL.FEASIBLE)
            # CL.setterminationstatus!(result, CL.OPTIMAL)
            # return result
        end

        problem, x, dec = CLD.GeneralizedAssignment.model_without_knp_constraints(data, coluna)

        master = BD.getmaster(dec)
        subproblems = BD.getsubproblems(dec)
        
        BD.specify!.(subproblems, lower_multiplicity = 0, solver = my_pricing_oracle)

        JuMP.optimize!(problem)
        @test JuMP.objective_value(problem) ≈ 75.0
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

end

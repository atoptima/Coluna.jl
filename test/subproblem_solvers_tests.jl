function subproblem_solvers_test()
    @testset "play gap with lazy cuts" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(
                conqueralg = ClA.ColCutGenConquer(max_nb_cut_rounds = 1000)
            )),
            "default_optimizer" => GLPK.Optimizer
        )

        model = BlockModel(coluna, direct_model = true)
        @axis(M, data.machines)
        @variable(model, x[m in M, j in data.jobs], Bin)
        @constraint(model, cov, sum(x[m,1] for m in M) == 1)  # add only covering constraint of job 1
        @constraint(model, knp[m in M],
            sum(data.weight[j,m]*x[m,j] for j in data.jobs) <= data.capacity[m]
        )
        @objective(model, Min,
            sum(data.cost[j,m]*x[m,j] for m in M, j in data.jobs)
        )
        @dantzig_wolfe_decomposition(model, dec, M)
        subproblems = BlockDecomposition.getsubproblems(dec)
        
        specify!(subproblems[1], lower_multiplicity=0, solver=JuMP.optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60 * 1_100, "msg_lev" => GLPK.GLP_MSG_OFF))
        specify!(subproblems[2], lower_multiplicity=0, solver=JuMP.optimizer_with_attributes(GLPK.Optimizer, "tm_lim" => 60 * 2_200))
        
        cur_j = 1
        # Lazy cut callback (add covering constraints on jobs on the fly)
        function my_callback_function(cb_data)
            for j in 1:cur_j 
                @test sum(callback_value(cb_data, x[m,j]) for m in M) ≈ 1
            end
            if cur_j < length(data.jobs)
                cur_j += 1
                con = @build_constraint(sum(x[m,cur_j] for m in M) == 1)
                MOI.submit(model, MOI.LazyConstraint(cb_data), con)
            end
        end
        MOI.set(model, MOI.LazyConstraintCallback(), my_callback_function)
        optimize!(model)
        @test JuMP.objective_value(model) ≈ 75.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
    end
end
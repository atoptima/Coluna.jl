function gurobi_generalized_assignment_tests()
    @testset "play gap" begin
        index = findfirst(x -> x.instance == "play gap", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("play gap"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 100.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 75.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "gap - JuMP/MOI modeling" begin
        index = findfirst(x -> x.instance == "gap - JuMP/MOI modeling", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("gap - JuMP/MOI modeling"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 500.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)
        @test JuMP.objective_value(model) ≈ 438.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "gap - strong branching" begin
        index = findfirst(x -> x.instance == "gap - strong branching", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("gap - strong branching"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("mediumgapcuts3.txt")

        branching = ClA.StrongBranching()
        push!(branching.phases, ClA.OnlyRestrictedMasterBranchingPhase(5))
        push!(branching.phases, ClA.ExactBranchingPhase(1))
        push!(branching.rules, ClA.PrioritisedBranchingRule(1.0, 1.0, ClA.VarBranchingRule()))

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = ClA.TreeSearchAlgorithm(dividealg = branching, maxnumnodes = 300)
            ),
            "default_optimizer" => Gurobi.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 2000.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 1553.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "gap - ColGen max nb iterations" begin
        index = findfirst(x -> x.instance == "gap - ColGen max nb iterations", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("gap - ColGen max nb iterations"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = ClA.TreeSearchAlgorithm(
                    conqueralg = ClA.ColGenConquer(
                        colgen = ClA.ColumnGeneration(max_nb_iterations = 8)
                    )
                )
            ),
            "default_optimizer" => Gurobi.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL # Problem with final dual bound ?
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "gap with penalties - pure master variables" begin
        index = findfirst(x -> x.instance == "gap with maximisation objective function", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("gap with maximisation objective function"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalties(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "gap with maximisation objective function" begin
        index = findfirst(x -> x.instance == "gap with maximisation objective function", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("gap with maximisation objective function"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model_max(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "gap with infeasible subproblem" begin
        index = findfirst(x -> x.instance == "gap with infeasible subproblem", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("gap with infeasible subproblem"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("root_infeas.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    @testset "play gap2" begin
        index = findfirst(x -> x.instance == "play gap2", algorithms)
        if index == nothing
            push!(algorithms, AlgorithmsKpis("play gap2"))
            algorithmkpis = algorithms[end]
        else
            algorithmkpis = algorithms[index]
        end

        if parallel
            push!(colunaruns, Runs("Coluna", ["Parallel"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
        else
            push!(colunaruns, Runs("Coluna", ["Sequential"]))
            push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
        end

        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)

        kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
            [:time]
        )
        merge!(algorithmkpis.kpis, kpis)
    end

    # @testset "play gap with no solver" begin
    #     if parallel
    #         push!(colunaruns, Runs("Coluna", ["Parallel"]))
    #         push!(solve_sps_runs, Runs("Solve Sps", ["Parallel"]))
    #     else
    #         push!(colunaruns, Runs("Coluna", ["Sequential"]))
    #         push!(solve_sps_runs, Runs("Solve Sps", ["Sequential"]))
    #     end
    #
    #     data = CLD.GeneralizedAssignment.data("play2.txt")
    #
    #     coluna = JuMP.optimizer_with_attributes(
    #         Coluna.Optimizer,
    #         "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
    #     )
    #
    #     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    #     try
    #         JuMP.optimize!(problem)
    #     catch e
    #         @test repr(e) == "ErrorException(\"Function `optimize!` is not defined for object of type Coluna.MathProg.NoOptimizer\")"
    #     end
    #
    #     kpis = calculateKpis([colunaruns[end], solve_sps_runs[end]],
    #         [:time]
    #     )
    #     algorithmkpis = AlgorithmsKpis("play gap with no solver", kpis)
    #     save_profiling_file("profilingtest.json", algorithmkpis)
    # end

    empty!(colunaruns)
    empty!(solve_sps_runs)
    return
end

function full_instances_tests()
    gurobi_generalized_assignment_tests()
    #generalized_assignment_tests()
    #capacitated_lot_sizing_tests()
    #lot_sizing_tests()
    #facility_location_tests()
    #cutting_stock_tests()
end

function gurobi_generalized_assignment_tests()
    @testset "play gap" begin
        push!(Coluna.colunaruns, Coluna.Runs("play gap", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("play gap", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("play gap", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "gap - JuMP/MOI modeling" begin
        push!(Coluna.colunaruns, Coluna.Runs("gap - JuMP/MOI modeling", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("gap - JuMP/MOI modeling", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("gap - JuMP/MOI modeling", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "gap - strong branching" begin
        push!(Coluna.colunaruns, Coluna.Runs("gap - strong branching", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("gap - strong branching", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("gap - strong branching", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "gap - ColGen max nb iterations" begin
        push!(Coluna.colunaruns, Coluna.Runs("gap - ColGen max nb iterations", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("gap - ColGen max nb iterations", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("gap - ColGen max nb iterations", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "gap with penalties - pure master variables" begin
        push!(Coluna.colunaruns, Coluna.Runs("gap with penalties - pure master variables", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("gap with penalties - pure master variables", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("gap with penalties - pure master variables", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "gap with maximisation objective function" begin
        push!(Coluna.colunaruns, Coluna.Runs("gap with maximisation objective function", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("gap with maximisation objective function", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("gap with maximisation objective function", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "gap with infeasible subproblem" begin
        push!(Coluna.colunaruns, Coluna.Runs("gap with infeasible subproblem", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("gap with infeasible subproblem", "Solve Sps"))

        data = CLD.GeneralizedAssignment.data("root_infeas.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => Gurobi.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("gap with infeasible subproblem", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "play gap" begin
        push!(Coluna.colunaruns, Coluna.Runs("play gap", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("play gap", "Solve Sps"))

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

        kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
            [:time]
        )
        algorithmkpis = Coluna.AlgorithmsKpis("play gap", kpis)
        Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    @testset "play gap with no solver" begin
        push!(Coluna.colunaruns, Coluna.Runs("play gap with no solver", "Coluna"))
        push!(Coluna.solve_sps_runs, Coluna.Runs("play gap with no solver", "Solve Sps"))

        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        try
            JuMP.optimize!(problem)
        catch e
            @test repr(e) == "ErrorException(\"Function `optimize!` is not defined for object of type Coluna.MathProg.NoOptimizer\")"
        end

        # kpis = Coluna.calculateKpis([Coluna.colunaruns[end], Coluna.solve_sps_runs[end]],
        #     [:time]
        # )
        # algorithmkpis = Coluna.AlgorithmsKpis("play gap with no solver", kpis)
        # Coluna.save_profiling_file("profilingtest.txt", algorithmkpis)
    end

    empty!(Coluna.colunaruns)
    empty!(Coluna.solve_sps_runs)
    return
end

function mytest()
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
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    BD.objectiveprimalbound!(model, 2000.0)
    BD.objectivedualbound!(model, 0.0)

    JuMP.optimize!(model)

    @test JuMP.objective_value(model) ≈ 1553.0
    @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
end

function generalized_assignment_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 100.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 75.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    end

    @testset "gap - JuMP/MOI modeling" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 500.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)
        @test JuMP.objective_value(model) ≈ 438.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    end

    @testset "gap - strong branching" begin
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
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 2000.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 1553.0
        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    end

    @testset "gap - ColGen max nb iterations" begin
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
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL # Problem with final dual bound ?
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    @testset "gap with penalties - pure master variables" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalties(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001
    end

    @testset "gap with maximisation objective function" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model_max(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
    end

    @testset "gap with infeasible subproblem" begin
        data = CLD.GeneralizedAssignment.data("root_infeas.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
    end

    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    @testset "play gap with no solver" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm())
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        try
            JuMP.optimize!(problem)
        catch e
            @test repr(e) == "ErrorException(\"Function `optimize!` is not defined for object of type Coluna.MathProg.NoOptimizer\")"
        end
    end
    return
end

function lot_sizing_tests()
    @testset "play single mode multi items lot sizing" begin
        data = CLD.SingleModeMultiItemsLotSizing.data("lotSizing-3-20-2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(
                solver = ClA.BendersCutGeneration()
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = CLD.SingleModeMultiItemsLotSizing.model(data, coluna)
        JuMP.optimize!(problem)
        @test 600 - 1e-6 <= objective_value(problem) <= 600 + 1e-6
    end
    return
end

function capacitated_lot_sizing_tests()
    @testset "clsp small instance" begin
        data = CLD.CapacitatedLotSizing.readData("testSmall")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, y, s, dec = CLD.CapacitatedLotSizing.model(data, coluna)
        JuMP.optimize!(model)

        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    end
end

function facility_location_tests()
    @testset "play facility location test " begin
        data = CLD.FacilityLocation.data("play.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(
                solver = ClA.BendersCutGeneration()
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = CLD.FacilityLocation.model(data, coluna)
        JuMP.optimize!(problem)
    end
    return
end

function cutting_stock_tests()
    @testset "play cutting stock" begin
        data = CLD.CuttingStock.data("randomInstances/inst10-10")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = CLD.CuttingStock.model(data, coluna)
        JuMP.optimize!(problem)
        @test 4 - 1e-6 <= objective_value(problem) <= 4 + 1e-6
    end
    return
end

using LightGraphs

function full_instances_tests()
    generalized_assignment_tests()
    capacitated_lot_sizing_tests()
    lot_sizing_tests()
    # facility_location_tests()
    cutting_stock_tests()
    cvrp_tests()
end

function generalized_assignment_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(
                branchingtreefile = "playgap.dot"
            )),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 100)
        BD.objectivedualbound!(model, 0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 75.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
        @test MOI.get(model, MOI.NumberOfVariables()) == length(x)
        @test MOI.get(model, MOI.SolverName()) == "Coluna"
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
        @test JuMP.termination_status(model) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    end
    
    @testset "gap - strong branching" begin
        data = CLD.GeneralizedAssignment.data("mediumgapcuts3.txt")

        conquer_with_small_cleanup_threshold = ClA.ColCutGenConquer(
            stages = [ClA.ColumnGeneration(cleanup_threshold = 150, smoothing_stabilization = 1.0)]
        )

        branching = ClA.StrongBranching(
            phases = [ClA.BranchingPhase(5, ClA.RestrMasterLPConquer()),
                      ClA.BranchingPhase(1, conquer_with_small_cleanup_threshold)],
            rules = [ClA.PrioritisedBranchingRule(ClA.SingleVarBranchingRule(), 2.0, 2.0),
                     ClA.PrioritisedBranchingRule(ClA.SingleVarBranchingRule(), 1.0, 1.0)]
        )

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = ClA.TreeSearchAlgorithm(
                    conqueralg = conquer_with_small_cleanup_threshold,
                    dividealg = branching,
                    maxnumnodes = 300
                )
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        # we increase the branching priority of variables which assign jobs to the first two machines
        for machine in 1:2
            for job in data.jobs
                BD.branchingpriority!(x[machine,job], 2)
            end
        end  

        BD.objectiveprimalbound!(model, 2000.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 1553.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    end


    @testset "gap - node limit" begin
        data = CLD.GeneralizedAssignment.data("mediumgapcuts3.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = ClA.TreeSearchAlgorithm(
                    maxnumnodes = 5
                )
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 2000.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(model)

        @test JuMP.objective_bound(model) ≈ 1547.3889
        @test JuMP.termination_status(model) == MathOptInterface.OTHER_LIMIT
        return
    end

    @testset "gap - ColGen max nb iterations" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = ClA.TreeSearchAlgorithm(
                    conqueralg = ClA.ColCutGenConquer(
                        stages = [ClA.ColumnGeneration(max_nb_iterations = 8)]
                    )
                )
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
        @test JuMP.termination_status(problem) == MOI.OPTIMAL # Problem with final dual bound ?
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
        @test JuMP.termination_status(problem) == MOI.OPTIMAL
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
        @test JuMP.termination_status(problem) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
    end

    @testset "gap with infeasible master" begin
        data = CLD.GeneralizedAssignment.data("master_infeas.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test JuMP.termination_status(problem) == MOI.INFEASIBLE
    end

    # Issue 520 : https://github.com/atoptima/Coluna.jl/issues/520
    @testset "gap with infeasible master 2" begin
        data = CLD.GeneralizedAssignment.data("master_infeas2.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test JuMP.termination_status(problem) == MOI.INFEASIBLE
    end

    @testset "gap with infeasible subproblem" begin
        data = CLD.GeneralizedAssignment.data("sp_infeas.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test JuMP.termination_status(problem) == MOI.INFEASIBLE
    end

    @testset "gap with all phases in col.gen" begin
        data = CLD.GeneralizedAssignment.data("mediumgapcuts1.txt")
        for m in data.machines
            data.capacity[m] = floor(Int, data.capacity[m] * 0.5)
        end

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(
                conqueralg = ClA.ColCutGenConquer(
                    stages = [ClA.ColumnGeneration(opt_rtol = 1e-4, smoothing_stabilization = 0.5)]
                )
            )),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalty(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 31895.0) <= 0.00001
    end

    @testset "gap with max. obj., pure mast. vars., and stabilization" begin
        data = CLD.GeneralizedAssignment.data("gapC-5-100.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = ClA.TreeSearchAlgorithm(
                    conqueralg = ClA.ColCutGenConquer(
                        stages = [ClA.ColumnGeneration(smoothing_stabilization = 1.0)]
                    ),
                    maxnumnodes = 300
                )
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, y, dec = CLD.GeneralizedAssignment.max_model_with_subcontracts(data, coluna)

        JuMP.optimize!(model)

        @test JuMP.objective_value(model) ≈ 3520.1
        @test JuMP.termination_status(model) == MOI.OPTIMAL
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
        @test JuMP.termination_status(problem) == MOI.OPTIMAL
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
            @test e isa ErrorException
        end
    end

    # We solve the GAP but only one set-partionning constraint (for job 1) is
    # put in the formulation before starting optimization.
    # Other set-partionning constraints are added in the essential cut callback.
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
        specify!.(subproblems, lower_multiplicity = 0)

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

    @testset "play gap with best dual bound" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.optimizer_with_attributes(
            CL.Optimizer,
            "params" => CL.Params(
                solver = Coluna.Algorithm.TreeSearchAlgorithm(
                    explorestrategy = Coluna.Algorithm.BestDualBoundStrategy()
                )
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        optimize!(model)
        @test JuMP.objective_value(model) ≈ 75.0
        @test JuMP.termination_status(model) == MOI.OPTIMAL
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

        @test JuMP.termination_status(model) == MOI.OPTIMAL
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

function cvrp_tests()
    @testset "play cvrp" begin
        data = CLD.CapacitatedVehicleRouting.data("A-n16-k3.vrp")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(
                maxnumnodes = 10000,
                branchingtreefile = "cvrp.dot"
            )),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.CapacitatedVehicleRouting.model(data, coluna)
        JuMP.optimize!(model)
        @test objective_value(model) ≈ 504
    end
    return
end

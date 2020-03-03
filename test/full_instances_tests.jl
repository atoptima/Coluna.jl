function full_instances_tests()
    generalized_assignment_tests()
    # capacitated_lot_sizing_tests()
    # lot_sizing_tests()
    # facility_location_tests()
    # cutting_stock_tests()
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
            solver = ClA.TreeSearchAlgorithm(dividealg = branching, maxnumnodes = 20)
        ),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    BD.objectiveprimalbound!(model, 2000.0)

    JuMP.optimize!(model)

    @test JuMP.objective_value(model) ≈ 1553.0
    @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, model, x)
end

function generalized_assignment_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer, 
            "params" => CL.Params(solver = ClA.TreeSearchAlgorithm()),
            "default_optimizer" => GLPK.Optimizer
        )

        model, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        BD.objectiveprimalbound!(model, 100.0)
        BD.objectivedualbound!(model, 0.0)

        JuMP.optimize!(problem)
        @test JuMP.objective_value(problem) == 443
        #@test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        #@test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        #@test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    # @testset "gap - JuMP/MOI modeling" begin
    #     data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    #     coluna = JuMP.with_optimizer(
    #         Coluna.Optimizer, params = CL.Params(
    #             global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
    #         ),
    #         default_optimizer = with_optimizer(GLPK.Optimizer)
    #     )

    #     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    #     JuMP.optimize!(problem)
    #     #@test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
    #     #@test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    #     #@test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    # end

    # @testset "gap - strong branching" begin
    #     data = CLD.GeneralizedAssignment.data("mediumgapcuts3.txt")

    #     branching = CL.BranchingStrategy()
    #     push!(branching.strong_branching_phases, 
    #           CL.only_restricted_master_branching_phase(5))
    #     push!(branching.strong_branching_phases, CL.exact_branching_phase(1))
    #     push!(branching.branching_rules, CL.VarBranchingRule())

    #     coluna = JuMP.with_optimizer(
    #         CL.Optimizer, params = CL.Params(
    #             max_num_nodes = 300,
    #             global_strategy = CL.GlobalStrategy(
    #                 CL.SimpleBnP(), 
    #                 branching, 
    #                 CL.DepthFirst()
    #             )
    #         ),
    #         default_optimizer = with_optimizer(GLPK.Optimizer)
    #     )

    #     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    #     JuMP.optimize!(problem)

    #     

        #@test abs(JuMP.objective_value(problem) - 1553.0) <= 0.00001
        #@test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        #@test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    #end


    # @testset "gap - ColGen max nb iterations" begin
    #     data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    #     coluna = JuMP.with_optimizer(
    #         Coluna.Optimizer, params = CL.Params(
    #             global_strategy = CL.GlobalStrategy(
    #                 CL.SimpleBnP(
    #                     colgen = CL.ColumnGeneration(
    #                         max_nb_iterations = 8
    #                     )
    #                 ),
    #                 CL.SimpleBranching(), 
    #                 CL.DepthFirst()
    #             )
    #         ),
    #         default_optimizer = with_optimizer(GLPK.Optimizer)
    #     )

    #     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    #     JuMP.optimize!(problem)
    #     @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
    #     @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    #     @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    # end

    # @testset "gap with penalties - pure master variables" begin
    #     data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    #     coluna = JuMP.with_optimizer(
    #         Coluna.Optimizer, params = CL.Params(
    #             global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
    #         ),
    #         default_optimizer = with_optimizer(GLPK.Optimizer)
    #     )

    #     problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalties(data, coluna)
    #     JuMP.optimize!(problem)
    #     @test JuMP.objective_value(problem) == 1556
    #     #@test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    #     #@test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001
    # end

    # @testset "gap with maximisation objective function" begin
    #     data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    #     coluna = JuMP.with_optimizer(
    #         Coluna.Optimizer, params = CL.Params(
    #             global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
    #         ),
    #         default_optimizer = with_optimizer(GLPK.Optimizer)
    #     )

    #     problem, x, dec = CLD.GeneralizedAssignment.model_max(data, coluna)
    #     JuMP.optimize!(problem)
    #     @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    #     @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
    # end

    # @testset "gap with infeasible subproblem" begin
    #     data = CLD.GeneralizedAssignment.data("root_infeas.txt")

    #     coluna = JuMP.with_optimizer(
    #         Coluna.Optimizer, params = CL.Params(
    #             global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
    #         ),
    #         default_optimizer = with_optimizer(GLPK.Optimizer)
    #     )
   
    #     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    #     JuMP.optimize!(problem)
    #     @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
    # end

    # @testset "gap BIG instance" begin
    #     data = CLD.GeneralizedAssignment.data("gapC-5-100.txt")

    # coluna = JuMP.with_optimizer(Coluna.Optimizer,
    #     default_optimizer = with_optimizer(GLPK.Optimizer)
    # )

    #     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    #     JuMP.optimize!(problem)
    #     @test abs(JuMP.objective_value(problem) - 1931.0) <= 0.00001
    #     @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    # end

    @testset "clsp small instance" begin
        data = CLD.CapacitatedLotSizing.readData("testSmall")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        model, x, y, s, dec = CLD.CapacitatedLotSizing.model(data, coluna)
        JuMP.optimize!(model)
        @test JuMP.objective_value(model) == 79.0

        #@test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
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

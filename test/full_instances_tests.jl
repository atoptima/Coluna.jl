function full_instances_tests()
    generalized_assignment_tests()
    #capacitated_lot_sizing_tests()
    #lot_sizing_tests()
    #facility_location_tests()
    cutting_stock_tests()
end

function generalized_assignment_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    @testset "gap - JuMP/MOI modeling" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    @testset "gap - ColGen max nb iterations" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(
                    CL.SimpleBnP(
                        colgen = CL.ColumnGeneration(
                            max_nb_iterations = 8
                        )
                    ),
                    CL.SimpleBranching(), 
                    CL.DepthFirst()
                )
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    @testset "gap with penalties - pure master variables" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalties(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001
    end

    @testset "gap with maximisation objective function" begin
        data = CLD.GeneralizedAssignment.data("smallgap3.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, dec = CLD.GeneralizedAssignment.model_max(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
    end

    @testset "gap with infeasible subproblem" begin
        data = CLD.GeneralizedAssignment.data("root_infeas.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst())
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )
   
        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
    end

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

    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        JuMP.optimize!(problem)
        @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
        @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
    end

    @testset "clsp small instance" begin
        data = CLD.CapacitatedLotSizing.readData("testSmall")

        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        model, x, y, s, dec = CLD.CapacitatedLotSizing.model(data, coluna)
        JuMP.optimize!(model)

        @test MOI.get(model.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    end
    return
end

function lot_sizing_tests()
    @testset "play single mode multi items lot sizing" begin
        data = CLD.SingleModeMultiItemsLotSizing.data("lotSizing-3-20-2.txt")
        
        coluna = JuMP.with_optimizer(Coluna.Optimizer,
            params = CL.Params(
                max_num_nodes = 1, 
                global_strategy = CL.GlobalStrategy(
                    CL.SimpleBenders(), CL.NoBranching(), CL.DepthFirst()
                )
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, y, dec = CLD.SingleModeMultiItemsLotSizing.model(data, coluna)
        JuMP.optimize!(problem)
        @test 600 - 1e-6 <= objective_value(problem) <= 600 + 1e-6
    end
    return
end

function capacitated_lot_sizing_tests()
    @testset "play multi items capacited lot sizing" begin
        data = CLD.CapacitatedLotSizing.readData("testSmall")
        
        coluna = JuMP.with_optimizer(
            Coluna.Optimizer, params = CL.Params(
                global_strategy = CL.GlobalStrategy(
                    CL.SimpleBnP(), CL.NoBranching(), CL.DepthFirst()
                )
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        clsp, x, y, s, dec = CLD.CapacitatedLotSizing.model(data, coluna)  
        JuMP.optimize!(clsp)
    end
end

function facility_location_tests()
    @testset "play facility locatio ntest " begin
        data = CLD.FacilityLocation.data("play.txt")
        
        coluna = JuMP.with_optimizer(
            Coluna.Optimizer,
            params = CL.Params(
                max_num_nodes = 1, 
                global_strategy = CL.GlobalStrategy(
                    CL.SimpleBenders(), CL.NoBranching(), CL.DepthFirst()
                )
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, y, dec = CLD.FacilityLocation.model(data, coluna)
        JuMP.optimize!(problem)
    end
    return
end

function cutting_stock_tests()
    @testset "play cutting stock" begin
        data = CLD.CuttingStock.data("randomInstances/inst10-10")

        coluna = JuMP.with_optimizer(Coluna.Optimizer,
            params = CL.Params(
                global_strategy = CL.GlobalStrategy(
                    CL.SimpleBnP(), CL.SimpleBranching(), CL.DepthFirst()
                )
            ),
            default_optimizer = with_optimizer(GLPK.Optimizer)
        )

        problem, x, y, dec = CLD.CuttingStock.model(data, coluna)
        JuMP.optimize!(problem)
        @test 4 - 1e-6 <= objective_value(problem) <= 4 + 1e-6
    end
    return
end

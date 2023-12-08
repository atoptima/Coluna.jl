function gap_toy_instance()
    data = ClD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => CL.Params(solver=ClA.BranchCutAndPriceAlgorithm(
                branchingtreefile="playgap.dot",
            ), local_art_var_cost=10000.0,
            global_art_var_cost=100000.0),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)
    BD.objectiveprimalbound!(model, 100)
    BD.objectivedualbound!(model, 0)

    JuMP.optimize!(model)

    @test JuMP.objective_value(model) ≈ 75.0
    @test JuMP.termination_status(model) == MOI.OPTIMAL
    @test JuMP.primal_status(model) == MOI.FEASIBLE_POINT
    # @show JuMP.value.(x)
    @test ClD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    @test MOI.get(model, MOI.NumberOfVariables()) == length(x)
    @test MOI.get(model, MOI.SolverName()) == "Coluna"
end
register!(e2e_tests, "gap", gap_toy_instance)

function gap_toy_instance_2()
    data = ClD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => CL.Params(solver=ClA.BranchCutAndPriceAlgorithm(
                jsonfile="playgap.json",
            ), local_art_var_cost=10000.0,
            global_art_var_cost=100000.0),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)
    BD.objectiveprimalbound!(model, 100)
    BD.objectivedualbound!(model, 0)

    JuMP.optimize!(model)

    @test JuMP.objective_value(model) ≈ 75.0
    @test JuMP.termination_status(model) == MOI.OPTIMAL
    @test JuMP.primal_status(model) == MOI.FEASIBLE_POINT
    # @show JuMP.value.(x)
    @test ClD.GeneralizedAssignment.print_and_check_sol(data, model, x)
    @test MOI.get(model, MOI.NumberOfVariables()) == length(x)
    @test MOI.get(model, MOI.SolverName()) == "Coluna"
end
register!(e2e_tests, "gap", gap_toy_instance_2)

function gap_strong_branching()
    data = ClD.GeneralizedAssignment.data("mediumgapcuts3.txt")

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "params" => CL.Params(
            solver=ClA.BranchCutAndPriceAlgorithm(
                maxnumnodes=300,
                colgen_stabilization=1.0,
                colgen_cleanup_threshold=150,
                stbranch_phases_num_candidates=[10, 3, 1],
                stbranch_intrmphase_stages=[(userstage=1, solverid=1, maxiters=2)]
            )
        ),
        "default_optimizer" => GLPK.Optimizer
    )

    model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)

    # we increase the branching priority of variables which assign jobs to the first two machines
    for job in data.jobs
        BD.branchingpriority!(x[1, job], 2)
    end
    for job in data.jobs
        BD.branchingpriority!(x[2, job], 2.0)
    end

    BD.objectiveprimalbound!(model, 2000.0)
    BD.objectivedualbound!(model, 0.0)

    JuMP.optimize!(model)

    @test JuMP.objective_value(model) ≈ 1553.0
    @test JuMP.termination_status(model) == MOI.OPTIMAL
    @test ClD.GeneralizedAssignment.print_and_check_sol(data, model, x)
end
register!(e2e_tests, "gap", gap_strong_branching)


# @testset "Generalized Assignment" begin
#     @testset "small instance" begin
#         data = ClD.GeneralizedAssignment.data("smallgap3.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)
#         BD.objectiveprimalbound!(model, 500.0)
#         BD.objectivedualbound!(model, 0.0)

#         JuMP.optimize!(model)
#         @test JuMP.objective_value(model) ≈ 438.0
#         @test JuMP.termination_status(model) == MOI.OPTIMAL
#         @test ClD.GeneralizedAssignment.print_and_check_sol(data, model, x)
#     end


#     @testset "node limit" begin # TODO -> replace by unit test for tree search algorithm
#         data = ClD.GeneralizedAssignment.data("mediumgapcuts3.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             CL.Optimizer,
#             "params" => CL.Params(
#                 solver = ClA.BranchCutAndPriceAlgorithm(
#                     maxnumnodes = 5
#                 )
#             ),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)
#         BD.objectiveprimalbound!(model, 2000.0)
#         BD.objectivedualbound!(model, 0.0)

#         JuMP.optimize!(model)

#         @test JuMP.objective_bound(model) ≈ 1547.3889
#         @test JuMP.termination_status(model) == MathOptInterface.OTHER_LIMIT
#         return
#     end

#     @testset "ColGen max nb iterations" begin
#         data = ClD.GeneralizedAssignment.data("smallgap3.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             CL.Optimizer,
#             "params" => CL.Params(
#                 solver = ClA.TreeSearchAlgorithm(
#                     conqueralg = ClA.ColCutGenConquer(
#                         stages = [ClA.ColumnGeneration(max_nb_iterations = 8)],
#                     )
#                 )
#             ),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, dec = ClD.GeneralizedAssignment.model(data, coluna)

#         JuMP.optimize!(problem)
#         @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
#         @test JuMP.termination_status(problem) == MOI.OPTIMAL # Problem with final dual bound ?
#         @test ClD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
#     end

#     @testset "pure master variables (GAP with f)" begin
#         data = ClD.GeneralizedAssignment.data("smallgap3.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, y, dec = ClD.GeneralizedAssignment.model_with_f(data, coluna)
#         JuMP.optimize!(problem)
#         @test JuMP.termination_status(problem) == MOI.OPTIMAL
#         @test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001
#     end

#     @testset "maximisation objective function" begin
#         data = ClD.GeneralizedAssignment.data("smallgap3.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, dec = ClD.GeneralizedAssignment.model_max(data, coluna)
#         JuMP.optimize!(problem)
#         @test JuMP.termination_status(problem) == MOI.OPTIMAL
#         @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
#     end

#     @testset "infeasible master" begin
#         data = ClD.GeneralizedAssignment.data("master_infeas.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, dec = ClD.GeneralizedAssignment.model(data, coluna)

#         JuMP.optimize!(problem)
#         @test JuMP.termination_status(problem) == MOI.INFEASIBLE
#     end

#     # Issue 520 : https://github.com/atoptima/Coluna.jl/issues/520
#     @testset "infeasible master 2" begin
#         data = ClD.GeneralizedAssignment.data("master_infeas2.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, dec = ClD.GeneralizedAssignment.model(data, coluna)

#         JuMP.optimize!(problem)
#         @test JuMP.termination_status(problem) == MOI.INFEASIBLE
#     end

#     @testset "infeasible subproblem" begin
#         data = ClD.GeneralizedAssignment.data("sp_infeas.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm()),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, dec = ClD.GeneralizedAssignment(data, coluna)

#         JuMP.optimize!(problem)
#         @test JuMP.termination_status(problem) == MOI.INFEASIBLE
#     end

#     @testset "gap with all phases in col.gen" begin # TODO: replace by unit tests for ColCutGenConquer.
#         data = ClD.GeneralizedAssignment.data("mediumgapcuts1.txt")
#         for m in M
#             data.capacity[m] = floor(Int, data.capacity[m] * 0.5)
#         end

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.TreeSearchAlgorithm(
#                 conqueralg = ClA.ColCutGenConquer(
#                     stages = [ClA.ColumnGeneration(opt_rtol = 1e-4, smoothing_stabilization = 0.5)]
#                 )
#             )),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         problem, x, y, dec = ClD.GeneralizedAssignment.model_with_penalty(data, coluna)

#         JuMP.optimize!(problem)
#         @test abs(JuMP.objective_value(problem) - 31895.0) <= 0.00001
#     end

#     @testset "gap with max. obj., pure mast. vars., and stabilization" begin
#         data = ClD.GeneralizedAssignment.data("gapC-5-100.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             CL.Optimizer,
#             "params" => CL.Params(
#                 solver = ClA.BranchCutAndPriceAlgorithm(
#                     colgen_stabilization = 1.0,
#                     maxnumnodes = 300
#                 )
#             ),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         model, x, y, dec = ClD.GeneralizedAssignment.max_model_with_subcontracts(data, coluna)

#         JuMP.optimize!(model)

#         @test JuMP.objective_value(model) ≈ 3520.1
#         @test JuMP.termination_status(model) == MOI.OPTIMAL
#     end

#     @testset "toy instance with no solver" begin
#         data = ClD.GeneralizedAssignment.data("play2.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm())
#         )

#         problem, x, dec = ClD.GeneralizedAssignment.model(data, coluna)
#         try
#             JuMP.optimize!(problem)
#         catch e
#             @test e isa ErrorException
#         end
#     end

#     # We solve the GAP but only one set-partionning constraint (for job 1) is
#     # put in the formulation before starting optimization.
#     # Other set-partionning constraints are added in the essential cut callback.
#     @testset "toy instance with lazy cuts" begin
#         data = ClD.GeneralizedAssignment.data("play2.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => CL.Params(solver = ClA.BranchCutAndPriceAlgorithm(
#                 max_nb_cut_rounds = 1000
#             )),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         model = BlockModel(coluna, direct_model = true)
#         @axis(M, M)
#         @variable(model, x[m in M, j in J], Bin)
#         @constraint(model, cov, sum(x[m,1] for m in M) == 1)  # add only covering constraint of job 1
#         @constraint(model, knp[m in M],
#             sum(data.weight[j,m]*x[m,j] for j in J) <= data.capacity[m]
#         )
#         @objective(model, Min,
#             sum(c[j,m]*x[m,j] for m in M, j in J)
#         )
#         @dantzig_wolfe_decomposition(model, dec, M)
#         subproblems = BlockDecomposition.getsubproblems(dec)
#         specify!.(subproblems, lower_multiplicity = 0)

#         cur_j = 1
#         # Lazy cut callback (add covering constraints on jobs on the fly)
#         function my_callback_function(cb_data)
#             for j in 1:cur_j
#                 @test sum(callback_value(cb_data, x[m,j]) for m in M) ≈ 1
#             end
#             if cur_j < length(J)
#                 cur_j += 1
#                 con = @build_constraint(sum(x[m,cur_j] for m in M) == 1)
#                 MOI.submit(model, MOI.LazyConstraint(cb_data), con)
#             end
#         end
#         MOI.set(model, MOI.LazyConstraintCallback(), my_callback_function)
#         optimize!(model)
#         @test JuMP.objective_value(model) ≈ 75.0
#         @test JuMP.termination_status(model) == MOI.OPTIMAL
#     end

#     @testset "toy instance with best dual bound" begin
#         data = ClD.GeneralizedAssignment.data("play2.txt")

#         coluna = JuMP.optimizer_with_attributes(
#             CL.Optimizer,
#             "params" => CL.Params(
#                 solver = Coluna.Algorithm.TreeSearchAlgorithm(
#                     explorestrategy = Coluna.Algorithm.BestDualBoundStrategy()
#                 )
#             ),
#             "default_optimizer" => GLPK.Optimizer
#         )

#         model, x, dec = ClD.GeneralizedAssignment.model(data, coluna)

#         optimize!(model)
#         @test JuMP.objective_value(model) ≈ 75.0
#         @test JuMP.termination_status(model) == MOI.OPTIMAL
#     end

#     @testset "toy instance with objective constant" begin
#         M = 1:3;
#         J = 1:15;
#         c = [12.7 22.5 8.9 20.8 13.6 12.4 24.8 19.1 11.5 17.4 24.7 6.8 21.7 14.3 10.5; 19.1 24.8 24.4 23.6 16.1 20.6 15.0 9.5 7.9 11.3 22.6 8.0 21.5 14.7 23.2;  18.6 14.1 22.7 9.9 24.2 24.5 20.8 12.9 17.7 11.9 18.7 10.1 9.1 8.9 7.7; 13.1 16.2 16.8 16.7 9.0 16.9 17.9 12.1 17.5 22.0 19.9 14.6 18.2 19.6 24.2];
#         w = [61 70 57 82 51 74 98 64 86 80 69 79 60 76 78; 50 57 61 83 81 79 63 99 82 59 83 91 59 99 91;91 81 66 63 59 81 87 90 65 55 57 68 92 91 86; 62 79 73 60 75 66 68 99 69 60 56 100 67 68 54];
#         Q = [1020 1460 1530];

#         coluna = optimizer_with_attributes(
#             Coluna.Optimizer,
#             "params" => Coluna.Params(
#                 solver = Coluna.Algorithm.TreeSearchAlgorithm() # default branch-cut-and-price
#             ),
#             "default_optimizer" => GLPK.Optimizer # GLPK for the master & the subproblems
#         );

#         model = BlockModel(coluna)
#         @axis(M_axis, M);
#         @variable(model, x[m in M_axis, j in J], Bin);
#         @constraint(model, cov[j in J], sum(x[m, j] for m in M_axis) >= 1);
#         @constraint(model, knp[m in M_axis], sum(w[m, j] * x[m, j] for j in J) <= Q[m]);
#         @objective(model, Min, sum(c[m, j] * x[m, j] for m in M_axis, j in J) + 250);
#         @dantzig_wolfe_decomposition(model, decomposition, M_axis)
#         subproblems = getsubproblems(decomposition)
#         specify!.(subproblems, lower_multiplicity = 0, upper_multiplicity = 1)
#         optimize!(model)

#         @test JuMP.objective_value(model) ≈ 250 + 166.5
#         return
#     end
# end
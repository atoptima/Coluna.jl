module ColunaTests
    using Base.CoreLogging: error
    using DynamicSparseArrays, Coluna

    using ReTest, GLPK, ColunaDemos, JuMP, BlockDecomposition, Random, MathOptInterface, MathOptInterface.Utilities, Base.CoreLogging, Logging
    global_logger(ConsoleLogger(stderr, LogLevel(0)))

    const MOI = MathOptInterface
    const MOIU = MOI.Utilities
    const MOIT = MOI.Test
    const MOIB = MOI.Bridges

    const CL = Coluna
    const ClD = ColunaDemos
    const BD = BlockDecomposition

    const ClB = Coluna.ColunaBase
    const ClMP = Coluna.MathProg
    const ClA = Coluna.Algorithm

    rng = MersenneTwister(1234123)

    ########################################################################################
    # Unit tests
    ########################################################################################
    for submodule in ["ColunaBase", "MathProg", "Algorithm"]
        dirpath = joinpath(@__DIR__, "unit", submodule)
        for filename in readdir(dirpath)
            include(joinpath(dirpath, filename))
        end
    end

    ########################################################################################
    # MOI integration tests
    ########################################################################################
    @testset "MOI integration" begin
        include("MathOptInterface/MOI_wrapper.jl")
    end

    ########################################################################################
    # E2E tests
    ########################################################################################
    dirpath = joinpath(@__DIR__, "e2e")
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end

    # ########################################################################################
    # # Bugfixes tests
    # ########################################################################################
    include("bugfixes.jl")

    ########################################################################################
    # Other tests
    ########################################################################################
    # include("interfaces/model.jl")
    # include("show_functions_tests.jl")
    # include("user_algorithms_tests.jl")
    # include("preprocessing_tests.jl")
    # include("pricing_callback_tests.jl")
    # include("bound_callback_tests.jl")
    # include("optimizer_with_attributes_test.jl")
    # include("subproblem_solvers_tests.jl")
    # include("custom_var_cuts_tests.jl")
    # include("sol_disaggregation_tests.jl")
    # include("node_finalizer_tests.jl")


    # @testset "Full instances " begin
    #     full_instances_tests()
    # end

    # @testset "User algorithms" begin
    #     user_algorithms_tests()
    # end

    # # @testset "Preprocessing " begin
    # #     preprocessing_tests()
    # # end

    # @testset "pricing callback" begin
    #     pricing_callback_tests()
    # end

    # @testset "bound callback" begin
    #     bound_callback_tests()
    # end

    # # @testset "Base.show functions " begin
    # #     backup_stdout = stdout
    # #     (rd_out, wr_out) = redirect_stdout()
    # #     show_functions_tests()
    # #     close(wr_out)
    # #     close(rd_out)
    # #     redirect_stdout(backup_stdout)
    # # end

    # @testset "Optimizer with Attributes" begin
    #     optimizer_with_attributes_test()
    # end

    # @testset "Subproblem Solvers" begin
    #     subproblem_solvers_test()
    # end

    # @testset "Custom Variables and Cuts" begin
    #     custom_var_cuts_test()
    # end

    # @testset "Solution Disaggregation" begin
    #     sol_disaggregation_tests()
    # end

    # @testset "Node Finalizer" begin
    #     node_finalizer_tests(false) # exact node finalizer

    #     node_finalizer_tests(true)  # heuristic node finalizer
    # end
end
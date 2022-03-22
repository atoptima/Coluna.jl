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
    dirpath = joinpath(@__DIR__, "old")
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end
end
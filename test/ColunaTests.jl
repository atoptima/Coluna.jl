module ColunaTests
    using Base.CoreLogging: error
    using DynamicSparseArrays, SparseArrays, Coluna, TOML

    using ReTest, GLPK, ColunaDemos, JuMP, BlockDecomposition, Random, MathOptInterface, MathOptInterface.Utilities, Base.CoreLogging, Logging
    global_logger(ConsoleLogger(stderr, LogLevel(0)))

    const MOI = MathOptInterface
    const MOIU = MOI.Utilities
    const MOIT = MOI.Test
    const MOIB = MOI.Bridges
    const CleverDicts = MOI.Utilities.CleverDicts

    const CL = Coluna
    const ClD = ColunaDemos
    const BD = BlockDecomposition

    const ClB = Coluna.ColunaBase
    const ClMP = Coluna.MathProg
    const ClA = Coluna.Algorithm

    rng = MersenneTwister(1234123)

    @testset "Version" begin
        coluna_ver = Coluna.version()
        toml_ver = VersionNumber(
            TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["version"]
        )
        @test coluna_ver == toml_ver   
    end

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
    # Integration tests
    ########################################################################################
    dirpath = joinpath(@__DIR__, "integration")
    for filename in readdir(dirpath)
        include(joinpath(dirpath, filename))
    end

    # ########################################################################################
    # # MOI integration tests
    # ########################################################################################
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
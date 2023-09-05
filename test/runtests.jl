using Revise

using Base.CoreLogging: error
using DynamicSparseArrays, SparseArrays, Coluna, TOML, JET

using Test, GLPK, ColunaDemos, JuMP, BlockDecomposition, Random, MathOptInterface, MathOptInterface.Utilities, Base.CoreLogging, Logging
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

using Coluna.ColunaBase, Coluna.MathProg, Coluna.ColGen, Coluna.Branching

include("TestRegistry/TestRegistry.jl")
using .TestRegistry

using Coluna.Tests.Parser

unit_tests = Registry()
integration_tests = Registry()
e2e_tests = Registry()
e2e_extra_tests = Registry()

const MODULES = [
    Coluna,
    Coluna.ColunaBase,
    Coluna.MustImplement,
    Coluna.MathProg,
    Coluna.Algorithm,
    Coluna.ColGen,
    Coluna.Branching,
    Parser
]

rng = MersenneTwister(1234123)

if !isempty(ARGS)
    # assume that the call is coming from revise.sh
    include("revise.jl")
else
    include("unit/run.jl")
    include("integration/run.jl")
    include("e2e/run.jl")
    include("e2e_extra/run.jl")

    run_unit_tests()
    run_integration_tests()

    @testset "MOI integration" begin
        include("MathOptInterface/MOI_wrapper.jl")
    end

    run_e2e_tests()
end

@testset "Version" begin
    coluna_ver = Coluna.version()
    toml_ver = VersionNumber(
        TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["version"]
    )
    @test coluna_ver == toml_ver   
end


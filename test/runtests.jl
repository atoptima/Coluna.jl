using Revise

using Base.CoreLogging: error
using DynamicSparseArrays, SparseArrays, Coluna, TOML

<<<<<<< HEAD
# retest(Coluna, ColunaTests)
=======
using Test, GLPK, ColunaDemos, JuMP, BlockDecomposition, Random, MathOptInterface, MathOptInterface.Utilities, Base.CoreLogging, Logging
global_logger(ConsoleLogger(stderr, LogLevel(0)))
>>>>>>> master

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

using Coluna.ColunaBase, Coluna.MathProg

include("TestRegistry/TestRegistry.jl")
using .TestRegistry

unit_tests = Registry()

const MODULES = [
    Coluna,
    Coluna.ColunaBase,
    Coluna.MustImplement,
    Coluna.MathProg,
    Coluna.Algorithm,
]

if !isempty(ARGS)
    # assume that the call is coming from revise.sh
    include("revise.jl")
end

rng = MersenneTwister(1234123)

include("parser.jl")

@testset "Version" begin
    coluna_ver = Coluna.version()
    toml_ver = VersionNumber(
        TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["version"]
    )
    @test coluna_ver == toml_ver   
end

include("unit/run.jl")

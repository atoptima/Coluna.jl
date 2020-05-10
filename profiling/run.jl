import Pkg
Pkg.activate(".")

using Coluna

using Test, GLPK, ColunaDemos, JuMP, BlockDecomposition, Gurobi
using Random

import MathOptInterface, MathOptInterface.Utilities

using Base.CoreLogging, Logging
global_logger(ConsoleLogger(stderr, LogLevel(0)))

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna
global const CLD = ColunaDemos
global const BD = BlockDecomposition

global const ClF = Coluna.MathProg # Must be deleted
global const ClMP = Coluna.MathProg
global const ClA = Coluna.Algorithm

rng = MersenneTwister(1234123)

include("profiling.jl")
include("gurobi_generalized_assigmment.jl")

global colunaruns = Runs[]
global solve_sps_runs = Runs[]
global algorithms = AlgorithmsKpis[]

@testset "Generalized Assigment " begin
    global parallel = false
    gurobi_generalized_assignment_tests()
    global parallel = true
    gurobi_generalized_assignment_tests()

    for alg in algorithms
        save_profiling_file("profilingtest.json", alg)
    end
end

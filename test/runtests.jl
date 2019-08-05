import Coluna

using Test, GLPK, ColunaDemos, JuMP, BlockDecomposition

import MathOptInterface, MathOptInterface.Utilities

using Base.CoreLogging, Logging
global_logger(ConsoleLogger(stderr, LogLevel(-4)))

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna
global const CLD = ColunaDemos
global const BD = BlockDecomposition

include("unit/unit_tests.jl")
include("show_functions_tests.jl")
include("full_instances_tests.jl")
include("preprocessing_tests.jl")
include("pricing_callback_tests.jl")

unit_tests()

@testset "Full instances " begin
    full_instances_tests()
end
@testset "Preprocessing " begin
    preprocessing_tests()
end
@testset "pricing callback" begin
    pricing_callback_tests()
end

@testset "Base.show functions " begin
    # Test show functions
    backup_stdout = stdout
    (rd_out, wr_out) = redirect_stdout()
    show_functions_tests()
    close(wr_out)
    close(rd_out)
    redirect_stdout(backup_stdout)
end

import Coluna

using Test

using GLPK
import MathOptInterface, MathOptInterface.Utilities

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna

include("unit/unit_tests.jl")

using Base.CoreLogging, Logging
global_logger(ConsoleLogger(stderr, LogLevel(1)))

unit_tests()

@testset "gap + csp - JuMP/MOI modeling" begin
    include("../examples/GeneralizedAssignment_SimpleColGen/run_sgap.jl")
    problem, x = sgap_play()
    JuMP.optimize!(problem)
    # model, x = sgap_5_100()
    # JuMP.optimize!(problem)

    #include("../examples/CuttingStock_SubprobMultiplicity/run_csp.jl")
    #run_csp_10_10()
    #run_csp_10_20()
end

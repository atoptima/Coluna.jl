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

include("../examples/GeneralizedAssignment_SimpleColGen/run_sgap.jl")

#@testset "cutting stock - colgen root " begin
#    testcolgenatroot()
#end
#@testset "knapsack - branch and bound" begin
#    branch_and_bound_test_instance()
#end
#branch_and_bound_bigger_instances()
#moi_wrapper()

# include("blackbox/runtests.jl")

@testset "gap + csp - JuMP/MOI modeling" begin
    model, x = sgap_play()
    JuMP.optimize!(model)
    model, x = sgap_5_100()
    JuMP.optimize!(model)

    #include("../examples/CuttingStock_SubprobMultiplicity/run_csp.jl")
    #run_csp_10_10()
    #run_csp_10_20()
end

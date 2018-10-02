import Coluna
# include("../src/Coluna.jl")

using Test

using GLPK
import MathOptInterface, MathOptInterface.Utilities

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna

include("utils.jl")
include("colunabasictests.jl")
include("colgenroot.jl")
include("moi_wrapper.jl")

# using Base.CoreLogging, Logging
# global_logger(ConsoleLogger(stderr, LogLevel(-5)))

testdefaultbuilders()
testpuremaster()
@testset "cutting stock - colgen root " begin
    testcolgenatroot()
end
@testset "knapsack - branch and bound" begin
    branch_and_bound_test_instance()
end
branch_and_bound_bigger_instances()
# moi_wrapper()
@testset "gap - JuMP/MOI modeling" begin
    include("../examples/GeneralizedAssignment_SimpleColGen/run_sgap.jl")
    include("../examples/CuttingStock_SubprobMultiplicity/run_csp.jl")
end

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
include("models/gap.jl")

@testset "play gap" begin
    println("\e[1;42m Classic Play GAP \e[00m")
    data = read_dataGap("../examples/GeneralizedAssignment_SimpleColGen/data/play2.txt")
    problem, x = sgap_play()
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 75.0) < 1e-5
    @test print_and_check_sol(data, problem, x)
end

@testset "gap - JuMP/MOI modeling" begin
    println("\e[1;42m Classic GAP \e[00m")
    data = read_dataGap("../examples/GeneralizedAssignment_SimpleColGen/data/smallgap3.txt")
    problem, x = model_sgap(data)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
    @test print_and_check_sol(data, problem, x)
end

@testset "gap with penalties - pure master variables" begin
    println("\e[1;42m GAP with penalties \e[00m")
    data = read_dataGap("../examples/GeneralizedAssignment_SimpleColGen/data/smallgap3.txt")
    problem, x = gap_with_penalties(data)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001
end

@testset "gap with maximisation objective function" begin
    println("\e[1;42m GAP maximization objective function \e[00m")
    data = read_dataGap("../examples/GeneralizedAssignment_SimpleColGen/data/smallgap3.txt")
    problem, x = maximization_gap(data)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
end

# @testset "gap - BIG" begin
#     println("\e[1;42m Big GAP 5 machines, 100 jobs \e[00m")
#     data = read_dataGap("../examples/GeneralizedAssignment_SimpleColGen/data/gapC-5-100.txt")
#     problem, x = sgap_5_100()
#     JuMP.optimize!(problem)
#     @test abs(JuMP.objective_value(problem) - 1931.0) < 1e-5
#     @test print_and_check_sol(data, problem, x)
# end

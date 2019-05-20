import Coluna

using Test, GLPK, ColunaDemos, JuMP

import MathOptInterface, MathOptInterface.Utilities

using Base.CoreLogging, Logging
global_logger(ConsoleLogger(stderr, LogLevel(1)))

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna
global const CLD = ColunaDemos

include("unit/unit_tests.jl")

unit_tests()

@testset "play gap" begin
    data = CLD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer))

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
end

@testset "gap - JuMP/MOI modeling" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer))

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 438.0) <= 0.00001
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
end

@testset "gap with penalties - pure master variables" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer)
    )

    problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalties(data, coluna)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 416.4) <= 0.00001
end

@testset "gap with maximisation objective function" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer)
    )

    problem, x, dec = CLD.GeneralizedAssignment.model_max(data, coluna)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 580.0) <= 0.00001
end

# @testset "gap BIG instance" begin
#     data = CLD.GeneralizedAssignment.data("gapC-5-100.txt")

#     coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
#         master_factory = with_optimizer(GLPK.Optimizer),
#         pricing_factory = with_optimizer(GLPK.Optimizer)
#     )

#     problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
#     JuMP.optimize!(problem)
#     @test abs(JuMP.objective_value(problem) - 1931.0) <= 0.00001
#     @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
# end

@testset "play gap" begin
    global_logger(ConsoleLogger(stderr, LogLevel(-4)))
    data = CLD.GeneralizedAssignment.data("play2.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer)
    )

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
end

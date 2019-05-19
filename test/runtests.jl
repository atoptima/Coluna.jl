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

@testset "gap - JuMP/MOI modeling" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer))

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    JuMP.optimize!(problem)
    #@show JuMP.objective_value(problem)
end

@testset "gap with penalties - pure master variables" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer)
    )

    problem, x, y, dec = CLD.GeneralizedAssignment.model_with_penalties(data, coluna)
    JuMP.optimize!(problem)
    #@test JuMP.objective_value(problem) == 416.4
end

@testset "gap with maximisation objective function" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer)
    )

    problem, x, dec = CLD.GeneralizedAssignment.model_max(data, coluna)
    JuMP.optimize!(problem)
    #@test JuMP.objective_value(problem) ==  416.4 ?
end
import Coluna

using Test, GLPK, ColunaDemos, JuMP

import MathOptInterface, MathOptInterface.Utilities

global const MOIU = MathOptInterface.Utilities
global const MOI = MathOptInterface
global const CL = Coluna
global const CLD = ColunaDemos

include("unit/unit_tests.jl")

using Base.CoreLogging, Logging
global_logger(ConsoleLogger(stderr, LogLevel(1)))

unit_tests()

@testset "gap - JuMP/MOI modeling" begin
    data = CLD.GeneralizedAssignment.data("play.txt")

    coluna = JuMP.with_optimizer(Coluna.Optimizer,# #params = params,
        master_factory = with_optimizer(GLPK.Optimizer),
        pricing_factory = with_optimizer(GLPK.Optimizer))

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    JuMP.optimize!(problem)
    #@show JuMP.objective_value(problem)
end

include("../examples/GeneralizedAssignment_SimpleColGen/run_sgap.jl")
include("models/gap.jl")
data_gap = read_dataGap("../examples/GeneralizedAssignment_SimpleColGen/data/smallgap3.txt")

@testset "gap with penalties - pure master variables" begin
    # JuMP.objective_value(problem) = 416.4
    problem = gap_with_penalties(data_gap)
    println("\e[1;42m GAP with penalties \e[00m")
    JuMP.optimize!(problem)
    #@show JuMP.objective_value(problem)
end

@testset "gap with maximisation objective function" begin
    # JuMP.objective_value(problem) = 416.4
    problem = maximization_gap(data_gap)
    println("\e[1;42m GAP maximization objective function \e[00m")
    JuMP.optimize!(problem)
    #@show JuMP.objective_value(problem)
end

    # model, x = sgap_5_100()
    # JuMP.optimize!(model)

    #include("../examples/CuttingStock_SubprobMultiplicity/run_csp.jl")
    #run_csp_10_10()
    #run_csp_10_20()
#end

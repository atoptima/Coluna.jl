using JuMP, Coluna, GLPK, Test, CPLEX, Gurobi
using MathOptInterface: set

# using Base.CoreLogging, Logging
# global_logger(ConsoleLogger(stderr, LogLevel(-5)))

include("data_csp.jl")
include("model_csp.jl")

function run_csp_10_10()
    appfolder = dirname(@__FILE__)
    data = read_dataCsp("$appfolder/data/randomInstances/inst10-10")
    (csp, x, y) = model_scsp(data)
    optimize!(csp)
    @show JuMP.objective_value(csp)
    @test JuMP.objective_value(csp) >= 4 - 10^(-6)
    @test JuMP.objective_value(csp) <= 4 + 10^(-6)
end

function run_csp_10_20()
    appfolder = dirname(@__FILE__)
    data = read_dataCsp("$appfolder/data/randomInstances/inst10-20")
    (csp, x, y) = model_scsp(data)
    optimize!(csp)
    @show JuMP.objective_value(csp)
    @test JuMP.objective_value(csp) >=  9 - 10^(-6)
    @test JuMP.objective_value(csp) <= 10 + 10^(-6)
end

function run_csp_20_10()
    appfolder = dirname(@__FILE__)
    data = read_dataCsp("$appfolder/data/randomInstances/inst20-10")
    (csp, x, y) = model_scsp(data)
    optimize!(csp)
    @show JuMP.objective_value(csp)
    @test JuMP.objective_value(csp) >= 13 - 10^(-6)
    @test JuMP.objective_value(csp) <= 13 + 10^(-6)
end

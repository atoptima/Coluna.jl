using JuMP, Coluna, Test
using MathOptInterface: set

# using Base.CoreLogging, Logging
# global_logger(ConsoleLogger(stderr, LogLevel(-5)))

include("data_csp.jl")
include("model_csp.jl")

appfolder = dirname(@__FILE__)
data = read_dataCsp("$appfolder/data/randomInstances/inst10-10")
solvertype = Coluna.ColunaModelOptimizer

(csp, x, y) = model_scsp(data, solvertype)

optimize!(csp)
@test JuMP.objective_value(csp) >= 4 - 10^(-6)
@test JuMP.objective_value(csp) <= 6 + 10^(-6)

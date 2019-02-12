using JuMP, Coluna, GLPK, Test, CPLEX
using MathOptInterface: set

# using Base.CoreLogging, Logging
# global_logger(ConsoleLogger(stderr, LogLevel(-5)))

include("data_csp.jl")
include("model_csp.jl")

appfolder = dirname(@__FILE__)

data = read_dataCsp("$appfolder/data/randomInstances/inst10-10")
(csp, x, y) = model_scsp(data)
optimize!(csp)
@show JuMP.objective_value(csp)
@test JuMP.objective_value(csp) >= 4 - 10^(-6)
@test JuMP.objective_value(csp) <= 4 + 10^(-6)

data = read_dataCsp("$appfolder/data/randomInstances/inst10-20")
(csp, x, y) = model_scsp(data)
optimize!(csp)
@show JuMP.objective_value(csp)
@test JuMP.objective_value(csp) >=  9 - 10^(-6)
@test JuMP.objective_value(csp) <= 10 + 10^(-6)


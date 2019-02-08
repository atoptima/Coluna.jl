using JuMP, GLPK, Coluna, Test
using MathOptInterface: set
#using Base.CoreLogging, Logging
#global_logger(ConsoleLogger(stderr, LogLevel(-4)))

include("data_sgap.jl")
include("model_sgap.jl")

appfolder = dirname(@__FILE__)
data = read_dataGap("$appfolder/data/play2.txt")
(gap, x) = model_sgap(data)
optimize!(gap)
@test abs(JuMP.objective_value(gap) - 75.0) < 1e-7

for m in data.machines, j in data.jobs
    if JuMP.value(x[m,j]) > 0
        println("job $(j) attached to machine $(m)")
    end
end

# NOT SUPPORTED YET
# status = JuMP.primal_status(gap)
#
# # Output
# println("Status is $status")
# if status == FeasiblePoint
#   println("Objective value : $(objective_value(gap))")
#   println("Aggregated solution : $(result_value(x))")
# end

# data = read_dataGap("$appfolder/data/gapC-5-100.txt")
# (gap, x) = model_sgap(data)
# optimize!(gap)
# @show JuMP.objective_value(gap)


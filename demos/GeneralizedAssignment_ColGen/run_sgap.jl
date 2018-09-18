using JuMP

include("data_sgap.jl")
include("model_sgap.jl")

appfolder = dirname(@__FILE__)
data = read_dataGap("$appfolder/data/play.txt")
# data = read_dataGap("$appfolder/data/gapC-5-100.txt")
solvertype = Coluna.ColunaModelOptimizer

(gap, x) = model_sgap(data, solvertype)

optimize!(gap)
@test JuMP.objective_value(gap) == 13.0

# NOT SUPPORTED YET
# status = JuMP.primal_status(gap)
# 
# # Output
# println("Status is $status")
# if status == FeasiblePoint
#   println("Objective value : $(objective_value(gap))")
#   println("Aggregated solution : $(result_value(x))")
# end

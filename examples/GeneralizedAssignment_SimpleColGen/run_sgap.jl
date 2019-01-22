using JuMP, GLPK, Coluna, Test
using MathOptInterface: set

include("data_sgap.jl")
include("model_sgap.jl")

appfolder = dirname(@__FILE__)
data = read_dataGap("$appfolder/data/play.txt")
# data = read_dataGap("$appfolder/data/gapC-5-100.txt")

(gap, x) = model_sgap(data)

optimize!(gap)
@test JuMP.objective_value(gap) == 13.0

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

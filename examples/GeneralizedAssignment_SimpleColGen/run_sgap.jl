using JuMP, GLPK, Coluna, Test, CPLEX
using MathOptInterface: set
#using Base.CoreLogging, Logging
#global_logger(ConsoleLogger(stderr, LogLevel(-4)))

include("data_sgap.jl")
include("model_sgap.jl")

appfolder = dirname(@__FILE__)

function print_sol(data, gap, x)
    for m in data.machines
        w = 0.0
        for j in data.jobs
            if JuMP.value(x[m,j]) > 0.9999
                println("job $(j) attached to machine $(m)")
                w += data.weight[j,m]
            end
        end
        println("Consumed ", w, " of machine ", m)
        println("Capacity of machine ", m, " is ", data.capacity[m])
    end
    @show JuMP.objective_value(gap)
end

data = read_dataGap("$appfolder/data/play2.txt")
(gap, x) = model_sgap(data)
optimize!(gap)
@test abs(JuMP.objective_value(gap) - 75.0) < 1e-7


# data = read_dataGap("$appfolder/data/gapC-5-100.txt")
# (gap, x) = model_sgap(data)
# optimize!(gap)


print_sol(data, gap, x)


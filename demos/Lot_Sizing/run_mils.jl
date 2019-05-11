using JuMP, GLPK, Coluna, Test#, CPLEX, Gurobi
using MathOptInterface: set
using BlockDecomposition
#using Base.CoreLogging, Logging
#global_logger(ConsoleLogger(stderr, LogLevel(-4)))

include("data_sgap.jl")
include("model_sgap.jl")

function print_and_check_sol(data, gap, x)
    sol_is_ok = true
    assigned = Set{Int}()
    for m in data.machines
        w = 0.0
        for j in data.jobs
            if JuMP.value(x[m,j]) > 0.9999
                println("job $(j) attached to machine $(m)")
                if j in assigned
                    println("Job ", j, " assigned to more than one machine.")
                    sol_is_ok = false
                end
                push!(assigned, j)
                w += data.weight[j,m]
            end
        end
        println("Consumed ", w, " of machine ", m, ". Capacity is ",
                data.capacity[m], ".")
        if w > data.capacity[m]
            sol_is_ok = false
        end
    end
    if length(assigned) != length(data.jobs)
        println("Not all jobs were assigned.")
        sol_is_ok = false
    end
    if sol_is_ok
        println("Solution is feasible.")
    else
        println("Solution is not feasible. :(")
    end
    @show JuMP.objective_value(gap)
    return sol_is_ok
end

function sgap_play()
    appfolder = dirname(@__FILE__)
    data = read_dataGap("$appfolder/data/play2.txt")
    return model_sgap(data)
    #optimize!(gap)
    #@test abs(JuMP.objective_value(gap) - 75.0) < 1e-5
    #@test print_and_check_sol(data, gap, x)
end

function sgap_5_100()
    appfolder = dirname(@__FILE__)
    data = read_dataGap("$appfolder/data/gapC-5-100.txt")
    return model_sgap(data)
    #optimize!(gap)
    #@test abs(JuMP.objective_value(gap) - 1931.0) < 1e-5
    #@test print_and_check_sol(data, gap, x)
end

function sgap_10_100()
    appfolder = dirname(@__FILE__)
    data = read_dataGap("$appfolder/data/gapC-10-100.txt")
    return model_sgap(data)
    #optimize!(gap)
    #@test abs(JuMP.objective_value(gap) - 1402.0) < 1e-5
    #@test print_and_check_sol(data, gap, x)
end

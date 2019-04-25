struct MasterIpHeuristic <: AbstractSolver end

struct MasterIpHeuristicData <: AbstractSolverData end

struct MasterIpHeuristicRecord <: AbstractSolverRecord
    time::Float64
end

function setup!(::Type{MasterIpHeuristic}, formulation, node)
    println("\e[32m setup master ip heuristic \e[00m")
end

function run!(::Type{MasterIpHeuristic}, solver_data, formulation, node, 
              parameters)
    println("Start Master IP Heuristic")
    println("FAKE CPLEX OUTPUT.")
    db = 1000
    pb = 2000
    for i in 1:rand(3:8)
        db += rand(100:0.01:200)
        pb -= rand(100:0.01:200)
        println("DB $db   --  PB $pb")
        sleep(0.2)
    end
    println("Found optimal solution")
    return MasterIpHeuristicRecord(7)
end

function setdown!(::Type{MasterIpHeuristic}, solver_data, formulation, node)
    println("setdown! masteripheur")
end

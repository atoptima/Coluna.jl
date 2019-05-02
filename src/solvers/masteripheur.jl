struct MasterIpHeuristic <: AbstractSolver end

struct MasterIpHeuristicData <: AbstractSolverData end

struct MasterIpHeuristicRecord <: AbstractSolverRecord
    time::Float64
end

function setup!(::Type{MasterIpHeuristic}, formulation, node)
    @warn "setup master ip heuristic"
end

function run!(::Type{MasterIpHeuristic}, solver_data, formulation, node, 
              parameters)
    @logmsg LogLevel(-1) "Applying Master IP heuristic"
    @warn "Restricted master ip heuristic not implemented yet."
    return MasterIpHeuristicRecord(7)
end

function setdown!(::Type{MasterIpHeuristic}, solver_data, formulation, node)
    @warn "setdown! masteripheur"
end

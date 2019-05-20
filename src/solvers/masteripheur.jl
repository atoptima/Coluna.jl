struct MasterIpHeuristic <: AbstractSolver end

struct MasterIpHeuristicData
    incumbents::Incumbents
end
MasterIpHeuristicData(S::Type{<:AbstractObjSense}) = MasterIpHeuristicData(Incumbents(S))

struct MasterIpHeuristicRecord <: AbstractSolverRecord
    incumbents::Incumbents
end

function prepare!(::Type{MasterIpHeuristic}, form, node, strategy_rec, params)
    @logmsg LogLevel(-1) "Prepare MasterIpHeuristic."
    return
end

function run!(::Type{MasterIpHeuristic}, form, node, strategy_rec, params)
    @logmsg LogLevel(1) "Applying Master IP heuristic"
    master = getmaster(form)
    solver_data = MasterIpHeuristicData(getobjsense(master))
    enforce_integrality!(master)
    status, value, p_sols, d_sol = optimize!(master)
    relax_integrality!(master)
    set_ip_primal_sol!(solver_data.incumbents, p_sols[1])
    @logmsg LogLevel(1) string("Found primal solution of ", get_ip_primal_bound(solver_data.incumbents))
    @logmsg LogLevel(-3) get_ip_primal_sol(solver_data.incumbents)
    # Record data 
    set_ip_primal_sol!(node.incumbents, get_ip_primal_sol(solver_data.incumbents))
    return MasterIpHeuristicRecord(solver_data.incumbents)
end

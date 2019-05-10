struct MasterIpHeuristic <: AbstractSolver end

struct MasterIpHeuristicData <: AbstractSolverData 
    incumbents::Incumbents
end
MasterIpHeuristicData(S::Type{<:AbstractObjSense}) = MasterIpHeuristicData(Incumbents(S))

struct MasterIpHeuristicRecord <: AbstractSolverRecord
    incumbents::Incumbents
end

function setup!(::Type{MasterIpHeuristic}, formulation::Reformulation, node,
                params)
    @logmsg LogLevel(-1) "Setup MasterIpHeuristic."
    return
end

function solverdata(::Type{MasterIpHeuristic}, formulation, node, params)
    return MasterIpHeuristicData(getobjsense(formulation.master))
end

function run!(::Type{MasterIpHeuristic}, solver_data::MasterIpHeuristicData, 
              formulation, node, params)

    @logmsg LogLevel(1) "Applying Master IP heuristic"
    enforce_integrality!(formulation.master)
    status, value, p_sols, d_sol = optimize!(formulation.master)
    relax_integrality!(formulation.master)
    set_ip_primal_sol!(solver_data.incumbents, p_sols[1])
    @logmsg LogLevel(1) string("Found primal solution of ", get_ip_primal_bound(solver_data.incumbents))
    @logmsg LogLevel(-3) get_ip_primal_sol(solver_data.incumbents)
    return MasterIpHeuristicRecord(solver_data.incumbents)
end

function setdown!(::Type{MasterIpHeuristic}, formulation, node, params)
    @logmsg LogLevel(-1) "Setdown of Master IP heuristic."
    solver_rec = get_solver_record!(node, MasterIpHeuristic)
    set_ip_primal_sol!(node.incumbents, get_ip_primal_sol(solver_rec.incumbents))
    return
end
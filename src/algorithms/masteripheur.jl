struct MasterIpHeuristic <: AbstractAlgorithm end

struct MasterIpHeuristicData
    incumbents::Incumbents
end
MasterIpHeuristicData(S::Type{<:AbstractObjSense}) = MasterIpHeuristicData(Incumbents(S))

struct MasterIpHeuristicRecord <: AbstractAlgorithmResult
    incumbents::Incumbents
end

function prepare!(algo::MasterIpHeuristic, form, node)
    @logmsg LogLevel(-1) "Prepare MasterIpHeuristic."
    return
end

function run!(algo::MasterIpHeuristic, form, node)
    @logmsg LogLevel(1) "Applying Master IP heuristic"
    master = getmaster(form)
    algorithm_data = MasterIpHeuristicData(getobjsense(master))
    if MOI.supports_constraint(getoptimizer(form.master).inner, MOI.SingleVariable, MOI.Integer)
        deactivate!(master, MasterArtVar)
        enforce_integrality!(master)
        opt_result = optimize!(master)
        relax_integrality!(master)
        activate!(master, MasterArtVar)
        update_ip_primal_sol!(algorithm_data.incumbents, getbestprimalsol(opt_result))
        @logmsg LogLevel(1) string("Found primal solution of ", get_ip_primal_bound(algorithm_data.incumbents))
        @logmsg LogLevel(-3) get_ip_primal_sol(algorithm_data.incumbents)
        # Record data 
        update_ip_primal_sol!(node.incumbents, get_ip_primal_sol(algorithm_data.incumbents))
    else
        @warn "Master optimizer does not support integer variables. Skip Restricted IP Master Heuristic."
    end
    return MasterIpHeuristicRecord(algorithm_data.incumbents)
end

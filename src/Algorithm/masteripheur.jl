struct MasterIpHeuristic <: AbstractOptimizationAlgorithm 
end

# struct MasterIpHeuristicData
#     incumbents::Incumbents
# end
# MasterIpHeuristicData(S::Type{<:Coluna.AbstractSense}) = MasterIpHeuristicData(Incumbents(S))

# struct MasterIpHeuristicRecord <: AbstractAlgorithmResult
#     incumbents::Incumbents
# end

# function prepare!(algo::MasterIpHeuristic, form, node)
#     @logmsg LogLevel(-1) "Prepare MasterIpHeuristic."
#     return
# end

function run!(algo::MasterIpHeuristic, reform::Reformulation, input::OptimizationInput)::OptimizationOutput
    @logmsg LogLevel(1) "Applying Master IP heuristic"

    initincumb = getincumbents(input)
    output = OptimizationOutput(initincumb)
    master = getmaster(reform)
    if MOI.supports_constraint(getoptimizer(master).inner, MOI.SingleVariable, MOI.Integer)

        # TO DO : enforce here the upper bound and maximum solution time    

        deactivate!(master, MasterArtVar)
        enforce_integrality!(master)
        opt_result = optimize!(master)
        relax_integrality!(master)
        activate!(master, MasterArtVar)

        @logmsg LogLevel(1) string(
            "Found primal solution of ", 
            @sprintf "%.4f" getprimalbound(opt_result)
        )
        @logmsg LogLevel(-3) getbestprimalsol(opt_result)

        # this heuristic can only update the primal ip solution
        # dual bound cannot be updated
        for sol in getprimalsols(opt_result)
            output.add_ip_primal_sol!(sol)
        end

        return output
    end

    @warn "Master optimizer does not support integer variables. Skip Restricted IP Master Heuristic."

    return output
end

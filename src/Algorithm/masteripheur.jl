struct MasterIpHeuristic <: AbstractOptimizationAlgorithm end

function run!(algo::MasterIpHeuristic, reform::Reformulation, input::OptimizationInput)::OptimizationOutput
    @logmsg LogLevel(1) "Applying Master IP heuristic"
    S = getobjsense(reform)
    initincumb = getincumbents(input)
    master = getmaster(reform)

    opt_result = OptimizationResult(master, initincumb)
    if MOI.supports_constraint(getoptimizer(master).inner, MOI.SingleVariable, MOI.Integer)
        # TO DO : enforce here the upper bound and maximum solution time    

        deactivate!(master, MasterArtVar)
        enforce_integrality!(master)
        moi_result = optimize!(master)

        relax_integrality!(master)
        activate!(master, MasterArtVar)

        setfeasibilitystatus!(opt_result, getfeasibilitystatus(moi_result))
        setterminationstatus!(opt_result, getterminationstatus(moi_result))

        bestprimalsol = getbestprimalsol(moi_result)
        if bestprimalsol !== nothing
            add_ip_primal_sol!(opt_result, bestprimalsol) 
        end

        @logmsg LogLevel(1) string(
            "Found primal solution of ", 
            @sprintf "%.4f" getvalue(get_ip_primal_bound(opt_result))
        )
        @logmsg LogLevel(-3) get_best_primal_sol(opt_result)

        return OptimizationOutput(opt_result)
    end

    @warn "Master optimizer does not support integer variables. Skip Restricted IP Master Heuristic."
    return OptimizationOutput(opt_result)
end

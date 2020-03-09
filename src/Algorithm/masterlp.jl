struct MasterLpAlgorithm <: AbstractOptimizationAlgorithm end

# struct MasterLpRecord <: AbstractAlgorithmResult
#     incumbents::Incumbents
#     proven_infeasible::Bool
# end

# function prepare!(algo::MasterLp, form, node)
#     @logmsg LogLevel(-1) "Prepare MasterLp."
#     return
# end

function run!(algo::MasterLpAlgorithm, reform::Reformulation, input::OptimizationInput)::OptimizationOutput

    initincumb = getincumbents(input)
    master = getmaster(reform)

    result = OptimizationResult(getmaster(reform), initincumb)    

    elapsed_time = @elapsed begin
        lpresult = TO.@timeit Coluna._to "LP restricted master" optimize!(master)
    end

    setfeasibilitystatus!(result, getfeasibilitystatus(lpresult))    
    setterminationstatus!(result, NOT_YET_DETERMINED)    
    lpsol = getbestprimalsol(lpresult)
    add_lp_primal_sol!(result, lpsol)

    # here we suppose that there are DW subproblems and thus the value of the LP solution
    # is not a valid dual bound, so the dual bound is not updated

    if isinteger(lpsol) && !contains(master, lpsol, MasterArtVar) &&
        update_ip_primal_bound!(initincumb, getprimalbound(lpresult))
        add_ip_primal_sol!(result, lpsol)
    end

    return OptimizationOutput(result)
end

struct MasterLpAlgorithm <: AbstractOptimizationAlgorithm end

# struct MasterLpRecord <: AbstractAlgorithmResult
#     incumbents::Incumbents
#     proven_infeasible::Bool
# end

# function prepare!(algo::MasterLp, form, node)
#     @logmsg LogLevel(-1) "Prepare MasterLp."
#     return
# end

function run!(algo::MasterLpAlgorithm, reform::Reformulation, initincumb::Incumbents)::OptimizationOutput

    master = getmaster(reform)

    output = OptimizationOutput(initincumb)    

    elapsed_time = @elapsed begin
        lpresult = TO.@timeit Coluna._to "LP restricted master" optimize!(master)
    end

    setfeasibilitystatus!(getfeasibilitystatus(lpresult))    
    setterminationstatus!(NOT_YET_DETERMINED)    
    lpsol = getbestprimalsol(lpresult)
    set_lp_primal_sol(output, lpsol)

    # here we suppose that there are DW subproblems and thus the value of the LP solution
    # is not a valid dual bound, so the dual bound is not updated

    if isinteger(lpsol) && !contains(master, lpsol, MasterArtVar)
        add_primal_sol!(output, lpsol)
    end

    return output
end

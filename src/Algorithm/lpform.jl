"""
    LpForm

todo
"""
Base.@kwdef struct LpForm <: AbstractOptimizationAlgorithm 
    relax_integrality = false
    log_level = 1
end

# struct MasterLpRecord <: AbstractAlgorithmResult
#     incumbents::Incumbents
#     proven_infeasible::Bool
# end

# function prepare!(algo::MasterLp, form, node)
#     @logmsg LogLevel(-1) "Prepare MasterLp."
#     return
# end

struct LpFormInput <: AbstractInput
    #incumbents::ObjValues{S} # needed ?
    # base ?
end

function run!(algo::LpForm, form::Formulation, input::LpFormInput)::OptimizationOutput
    algoresult = OptimizationResult(form)

    if algo.relax_integrality
        relax_integrality!(form)
    end

    optimizer_result = optimize!(form)

    setfeasibilitystatus!(algoresult, getfeasibilitystatus(optimizer_result))    
    setterminationstatus!(algoresult, getterminationstatus(optimizer_result))   

    lpsol = getbestprimalsol(optimizer_result)
    if lpsol !== nothing
        add_lp_primal_sol!(algoresult, lpsol)

        # here we suppose that there are DW subproblems and thus the value of the LP solution
        # is not a valid dual bound, so the dual bound is not updated -> we should suppose nothing
        if isinteger(lpsol) && !contains(lpsol, varid -> isanArtificialDuty(getduty(varid)))
            add_ip_primal_sol!(algoresult, lpsol)
        end
    end

    return OptimizationOutput(algoresult)
end

"""
    SolveLpForm

todo
"""
Base.@kwdef struct SolveLpForm <: AbstractOptimizationAlgorithm 
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

struct SolveLpFormInput <: AbstractInput
    #incumbents::ObjValues{S} # needed ?
    # base ?
end

function run!(algo::SolveLpForm, form::Formulation, input::SolveLpFormInput)::OptimizationOutput
    algoresult = OptimizationState(form)

    if algo.relax_integrality
        relax_integrality!(form)
    end

    optimizer_result = optimize!(form)

    setfeasibilitystatus!(algoresult, getfeasibilitystatus(optimizer_result))    
    setterminationstatus!(algoresult, getterminationstatus(optimizer_result))   

    lp_primal_sol = getbestprimalsol(optimizer_result)
    if lp_primal_sol !== nothing
        add_lp_primal_sol!(algoresult, lp_primal_sol)
        add_lp_dual_sol!(algoresult, getbestdualsol(optimizer_result))
        # here we suppose that there are DW subproblems and thus the value of the LP solution
        # is not a valid dual bound, so the dual bound is not updated -> we should suppose nothing
        if isinteger(lp_primal_sol) && !contains(lp_primal_sol, varid -> isanArtificialDuty(getduty(varid)))
            add_ip_primal_sol!(algoresult, lp_primal_sol)
        end
    end

    return OptimizationOutput(algoresult)
end

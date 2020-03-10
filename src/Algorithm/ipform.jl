"""
    IpForm

todo
Deactivate artificial variables and solve formulation with optimizer
"""
Base.@kwdef struct IpForm <: AbstractOptimizationAlgorithm
    time_limit::Int = 600
end

# TODO : content of OptimizationInput ? 
#
# struct IpFormInput <: AbstractOptimizationInput
#    incumbents::ObjValues{S}
# end

function run!(algo::IpForm, form::Formulation, input::OptimizationInput)::OptimizationOutput
    @logmsg LogLevel(1) "Algorithm IpForm"
    initincumb = getincumbents(input)
    optresult = OptimizationResult(form, initincumb)
    optimizer = getoptimizer(form).inner

    if MOI.supports_constraint(optimizer, MOI.SingleVariable, MOI.Integer)
        MOI.set(optimizer, MOI.TimeLimitSec(), algo.time_limit)
        # No way to enforce upper bound through MOI. 
        # Add a constraint c'x <= UB in form ?

        deactivate!(form, vcid -> isanArtificialDuty(getduty(vcid)))
        enforce_integrality!(form)
        moiresult = optimize!(form)

        relax_integrality!(form)
        activate!(form, vcid -> isanArtificialDuty(getduty(vcid)))

        setfeasibilitystatus!(optresult, getfeasibilitystatus(moiresult))
        setterminationstatus!(optresult, getterminationstatus(moiresult))

        bestprimalsol = getbestprimalsol(moiresult)
        if bestprimalsol !== nothing
            add_ip_primal_sol!(optresult, bestprimalsol) 

            @logmsg LogLevel(1) string(
                "Found primal solution of ", 
                @sprintf "%.4f" getvalue(get_ip_primal_bound(optresult))
            )
            @logmsg LogLevel(-3) get_best_ip_primal_sol(optresult)
        else
            @logmsg LogLevel(1) string(
                "No primal solution found. Termination status is ", 
                getterminationstatus(optresult), ". Feasibility status is ",
                getfeasibilitystatus(optresult), "."
            )
        end
        return OptimizationOutput(optresult)
    end
    @warn "Optimizer of formulation with id =", getuid(form) ," does not support integer variables. Skip IpForm algorithm."
    return OptimizationOutput(optresult)
end
"""
todo
"""
@with_kw struct PricingCallback <: AbstractOptimizationAlgorithm
    stage::Int = 1 # stage 1 is the exact stage by convention,
                   # any other stage is heuristic
    max_nb_ip_primal_sols = 50
end

function get_units_usage(algo::PricingCallback, spform::Formulation{DwSp}) 
    units_usage = Tuple{AbstractModel, UnitType, UnitAccessMode}[] 
    push!(units_usage, (spform, StaticVarConstrUnit, READ_ONLY))
    return units_usage
end

function run!(
    algo::PricingCallback, env::Env, spform::Formulation{DwSp}, input::OptimizationInput, 
    optimizer_id::Int = 1
)::OptimizationOutput
    result = OptimizationState(
        spform, 
        ip_primal_bound = get_ip_primal_bound(getoptstate(input)),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    @logmsg LogLevel(-2) "Calling user-defined optimization function."

    optimizer = getoptimizer(spform, optimizer_id)
    cbdata = MathProg.PricingCallbackData(spform, algo.stage)
    optimizer.user_oracle(cbdata)

    if length(cbdata.primal_solutions) > 0
        for primal_sol in cbdata.primal_solutions
            add_ip_primal_sol!(result, primal_sol)
        end

        if algo.stage == 1 # stage 1 is exact by convention
            dual_bound = getvalue(get_ip_primal_bound(result))
            set_ip_dual_bound!(result, DualBound(spform, dual_bound))
            setterminationstatus!(result, OPTIMAL) 
        else    
            setterminationstatus!(result, OTHER_LIMIT) 
        end
    else
        if algo.stage == 1    
            setterminationstatus!(result, INFEASIBLE) 
        else
            setterminationstatus!(result, OTHER_LIMIT) 
        end 
    end
    
    return OptimizationOutput(result)
end

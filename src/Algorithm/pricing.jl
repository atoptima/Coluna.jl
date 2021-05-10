####################################################################
#                      PricingCallback
####################################################################

@with_kw struct PricingCallback <: AbstractOptimizationAlgorithm
    stagenumber::Int = 1 
    max_nb_ip_primal_sols = 50
end

function get_units_usage(algo::PricingCallback, spform::Formulation{DwSp}) 
    units_usage = Tuple{AbstractModel, UnitType, UnitAccessMode}[] 
    push!(units_usage, (spform, StaticVarConstrUnit, READ_ONLY))
    return units_usage
end

function run!(algo::PricingCallback, env::Env, spform::Formulation{DwSp}, input::OptimizationInput)::OptimizationOutput
    result = OptimizationState(
        spform, 
        ip_primal_bound = get_ip_primal_bound(getoptstate(input)),
        max_length_ip_primal_sols = algo.max_nb_ip_primal_sols
    )

    @logmsg LogLevel(-2) "Calling user-defined optimization function."

    optimizer = getuseroptimizer(spform)
    cbdata = MathProg.PricingCallbackData(spform, algo.stagenumber)
    optimizer.user_oracle(cbdata)

    if length(cbdata.primal_solutions) > 0
        for primal_sol in cbdata.primal_solutions
            add_ip_primal_sol!(result, primal_sol)
        end

        if algo.stagenumber == 1 
            dual_bound = getvalue(get_ip_primal_bound(result))
            set_ip_dual_bound!(result, DualBound(spform, dual_bound))
            setterminationstatus!(result, OPTIMAL)
        else    
            setterminationstatus!(result, OTHER_LIMIT)
        end
    else
        setterminationstatus!(result, INFEASIBLE) # TODO : what if no solution found ?
    end

    return OptimizationOutput(result)
end

####################################################################
#                      PricingAlgorithm
####################################################################

@with_kw struct PricingAlgorithm <: AbstractOptimizationAlgorithm
    callbackalg::PricingCallback = PricingCallback()
    MIPalg::SolveIpForm = SolveIpForm(deactivate_artificial_vars=false, enforce_integrality=false, log_level=2)
    dispatch::Int = 0 # 0 - automatic, 1 - impose pricing callback, 2 - impose pricing by MIP 
end

function get_child_algorithms(algo::PricingAlgorithm, spform::Formulation{DwSp}) 
    child_algs = Tuple{AbstractAlgorithm,AbstractModel}[]
    algo.dispatch != 2 && push!(child_algs, (algo.callbackalg, spform))
    algo.dispatch != 1 && push!(child_algs, (algo.MIPalg, spform))
    return child_algs
end 

function run!(algo::PricingAlgorithm, env::Env, spform::Formulation{DwSp}, input::OptimizationInput)::OptimizationOutput

    if algo.dispatch == 1 && !isa(getuseroptimizer(spform), UserOptimizer)
        @error string("Pricing callback is imposed but not defined")
    end 

    if algo.dispatch != 2 && isa(getuseroptimizer(spform), UserOptimizer)
        return run!(algo.callbackalg, env, spform, input)
    end

    return run!(algo.MIPalg, env, spform, input)
end
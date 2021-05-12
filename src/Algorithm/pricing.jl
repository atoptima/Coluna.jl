@with_kw struct DefaultPricing <: AbstractOptimizationAlgorithm
    callbackalg::PricingCallback = PricingCallback()
    MIPalg::SolveIpForm = SolveIpForm(deactivate_artificial_vars=false, enforce_integrality=false, log_level=2)
    dispatch::Int = 0 # 0 - automatic, 1 - impose pricing callback, 2 - impose pricing by MIP 
end

function get_child_algorithms(algo::DefaultPricing, spform::Formulation{DwSp}) 
    child_algs = Tuple{AbstractAlgorithm,AbstractModel}[]
    algo.dispatch != 2 && push!(child_algs, (algo.callbackalg, spform))
    algo.dispatch != 1 && push!(child_algs, (algo.MIPalg, spform))
    return child_algs
end 

function run!(algo::DefaultPricing, env::Env, spform::Formulation{DwSp}, input::OptimizationInput)::OptimizationOutput

    if algo.dispatch == 1 && !isa(getuseroptimizer(spform), UserOptimizer)
        @error string("Pricing callback is imposed but not defined")
    end 

    if algo.dispatch != 2 && isa(getuseroptimizer(spform), UserOptimizer)
        return run!(algo.callbackalg, env, spform, input)
    end

    return run!(algo.MIPalg, env, spform, input)
end
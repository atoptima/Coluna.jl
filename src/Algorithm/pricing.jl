@with_kw struct DefaultPricing <: AbstractOptimizationAlgorithm
    pricing_callback::PricingCallback = PricingCallback()
    solve_ip_form::SolveIpForm = SolveIpForm(deactivate_artificial_vars=false, enforce_integrality=false, log_level=2)
    optimizer_id::Int = 1
end

_child_algorithm(algo::DefaultPricing, ::MoiOptimizer) = algo.solve_ip_form
_child_algorithm(algo::DefaultPricing, ::UserOptimizer) = algo.pricing_callback
_child_algorithm(::DefaultPricing, ::NoOptimizer) = nothing

function get_child_algorithms(algo::DefaultPricing, spform::Formulation{DwSp}) 
    child_algs = Tuple{AbstractAlgorithm,AbstractModel}[]
    opt = getoptimizer(spform, algo.optimizer_id)
    if _child_algorithm(algo, opt) !== nothing
        push!(child_algs, (_child_algorithm(algo, opt), spform))
    end
    return child_algs
end

function run!(algo::DefaultPricing, env::Env, spform::Formulation{DwSp}, input::OptimizationInput)::OptimizationOutput
    opt = getoptimizer(spform, algo.optimizer_id)
    if _child_algorithm(algo, opt) !== nothing
        return run!(_child_algorithm(algo, opt), env, spform, input, algo.optimizer_id)
    end
    return error("Cannot optimize LP formulation with optimizer of type $(typeof(opt)).")
end
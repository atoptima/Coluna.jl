#############################################################################
# Pricing strategy
#############################################################################
struct ClassicColGenPricingStrategy <: ColGen.AbstractPricingStrategy
    subprobs::Dict{FormId, Formulation{DwSp}}
end

ColGen.get_pricing_strategy(ctx::ColGen.AbstractColGenContext, _) = ClassicColGenPricingStrategy(ColGen.get_pricing_subprobs(ctx))
ColGen.pricing_strategy_iterate(ps::ClassicColGenPricingStrategy) = iterate(ps.subprobs)
ColGen.pricing_strategy_iterate(ps::ClassicColGenPricingStrategy, state) = iterate(ps.subprobs, state)

#############################################################################
# Column generation
#############################################################################
function ColGen.compute_sp_init_db(ctx::ClassicColGenPricingStrategy)
    return ctx.optim_sense == MinSense ? -Inf : Inf
end

function ColGen.set_of_columns(ctx::ClassicColGenPricingStrategy)
    return nothing
end

function ColGen.optimize_pricing_problem!(ctx::ClassicColGenPricingStrategy, sp::Formulation{DwSp})
    println("\e[34m optimize_pricing_problem! \e[00m")
end

ColGen.get_primal_sols(pricing_res) = nothing
ColGen.get_dual_bound(pricing_res) = nothing
ColGen.push_in_set!(pool, column) = nothing

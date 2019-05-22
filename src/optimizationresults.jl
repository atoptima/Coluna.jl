"""
    OptimizationResult{S}

Structure to be returned by all Coluna `optimize!` methods.
"""
mutable struct OptimizationResult{S<:AbstractObjSense}
    feasible::Bool # True iff feasible
    primal_bound::PrimalBound{S}
    dual_bound::PrimalBound{S}
    primal_sols::Vector{PrimalSolution{S}}
    dual_sols::Vector{DualSolution{S}}
end

"""
    OptimizationResult{S}()

Builds an empty OptimizationResult.
"""
OptimizationResult{S}() where {S} = OptimizationResult{S}(
    true, PrimalBound{S}(), DualBound{S}(), PrimalSolution{S}[],
    DualSolution{S}[]
)

isfeasible(res::OptimizationResult) = res.feasible
getprimalbound(res::OptimizationResult) = res.primal_bound
getdualbound(res::OptimizationResult) = res.dual_bound
getprimalsols(res::OptimizationResult) = res.primal_sols
getdualsols(res::OptimizationResult) = res.dual_sols
getbestprimalsol(res::OptimizationResult) = res.primal_sols[1]
getbestdualsol(res::OptimizationResult) = res.dual_sols[1]

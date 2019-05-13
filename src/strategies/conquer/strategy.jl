"""
    AbstractConquerStrategy

Conquer strategy is a combination of `Solvers` to treat a node of the
branch-and-bound tree.
"""
abstract type AbstractConquerStrategy <: AbstractStrategy end

# """
#     apply!(::Type{<:AbstractConquerStrategy}, reformulation, node, strategy_record, params)

# Applies the conquer strategy on a `reformulation` in the `node` with `parameters`.
# """
# Fallback
function apply!(S::Type{<:AbstractConquerStrategy}, reform, node, 
                strategy_rec::StrategyRecord, params)
    error("Method apply! not implemented for conquer strategy $S.")
end
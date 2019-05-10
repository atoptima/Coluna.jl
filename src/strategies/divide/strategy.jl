"""
    AbstractDivideStrategy

Divide strategy is a combination of `Solvers`that generates one or more children
branch-and-bound node.
"""
abstract type AbstractDivideStrategy <: AbstractStrategy end

"""
    apply!(::Type{<:AbstractDivideStrategy}, reformulation, node, strategy_record, params)

Applies the divide strategy on a `reformulation` in the `node` with `parameters`.
"""
function apply!(S::Type{<:AbstractDivideStrategy}, reform, node, 
                strategy_rec::StrategyRecord, params)
    error("Method apply! not implemented for divide strategy $S.")
end
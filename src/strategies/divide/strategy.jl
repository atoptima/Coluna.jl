abstract type AbstractDivideStrategy <: AbstractStrategy end

function apply!(S::Type{<:AbstractDivideStrategy}, reform, node, 
                strategy_rec::StrategyRecord, params)
    error("Method apply! not implemented for branching strategy $S.")
end
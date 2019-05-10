abstract type AbstractConquerStrategy <: AbstractStrategy end

function apply!(S::Type{<: AbstractConquerStrategy}, reform, node, 
                record::StrategyRecord, params)
    error("Method apply! not implemented for conquer strategy $S.")
end
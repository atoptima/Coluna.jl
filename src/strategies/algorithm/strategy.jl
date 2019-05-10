abstract type AbstractAlgorithmStrategy <: AbstractStrategy end

function apply!(S::Type{<: AbstractAlgorithmStrategy}, reform, node, 
                record::StrategyRecord, params)
    error("Method apply! not implemented for algorithm strategy $S.")
end
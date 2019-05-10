abstract type AbstractBranchingStrategy <: AbstractStrategy end

function apply!(S::Type{<: AbstractBranchingStrategy}, reform, node, 
                record::StrategyRecord, params)
    error("Method apply! not implemented for branching strategy $S.")
end
struct SimpleBranching <: AbstractDivideStrategy end

function apply!(S::Type{<:SimpleBranching}, reform, node, 
                strategy_rec::StrategyRecord, params)
    gcn_rec = apply!(GenerateChildrenNode, reform, node, strategy_rec, params) 
    return
end

struct NoBranching <: AbstractDivideStrategy end
function apply!(S::Type{<:NoBranching}, reform, node, 
                strategy_rec::StrategyRecord, params)
    return
end

struct SimpleBranching <: AbstractBranchingStrategy end

function apply!(S::Type{<:SimpleBranching}, reform, node, 
                record::StrategyRecord, params)
    gen_children = apply!(GenerateChildrenNode, reform, node, record, params) 
    return
end
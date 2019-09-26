struct SimpleBranching <: AbstractDivideStrategy end

function apply!(strategy::SimpleBranching, reform, node)
    gcn_rec = apply!(GenerateChildrenNode(), reform, node) 
    return
end

struct NoBranching <: AbstractDivideStrategy end
function apply!(strategy::NoBranching, reform, node)
    return
end

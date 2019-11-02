struct SimpleBranching <: AbstractDivideStrategy end

# function apply!(strategy::SimpleBranching, reform::Reformulation, node::Node, treat_order::Int64)
#     gcn_rec = apply!(GenerateChildrenNode(), reform, node, treat_order) 
#     return
# end

struct NoBranching <: AbstractDivideStrategy end
function apply!(strategy::NoBranching, reform::Reformulation, node::Node, treat_order::Int64)
    return
end

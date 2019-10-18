"""
    BranchingGroup

    Contains a branching candidate together with additional "local" information needed during current branching
"""
mutable struct BranchingGroup
    candidate::AbstractBranchingCandidate
    local_id::Int64
    lhs::Float64
    from_history::Bool    
    children::Vector{Node}
    tree_depth_score::Float64
    product_score::Float64
end

function BranchingGroup(candidate_::AbstractBranchingCandidate, local_id_::Int64, lhs_::Float64)
    return BranchingGroup(candidate_, local_id_, lhs_, false, Vector{Node}(), typemax(Float64), 0.0)
end
    
get_lhs_distance_to_integer(group::BranchingGroup) = 
    min(group.lhs - floor(group.lhs), ceil(group.lhs) - group.lhs)    

function generate_children!(group::BranchingGroup, reform::Reformulation, parent::Node)
    group.children = generate_children(group.candidate, group.lhs, reform, parent)
end

function regenerate_children!(group::BranchingGroup, reform::Reformulation, parent::Node)
    new_children = Vector{Node}()

    for child in group.children
        push!(new_children, Node(parent, child))
    end
    group.children = new_children
end

#function compute_product_score!()


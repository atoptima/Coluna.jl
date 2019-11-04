"""
    BranchingGroup

    Contains a branching candidate together with additional "local" information needed during current branching
"""
mutable struct BranchingGroup
    candidate::AbstractBranchingCandidate
    local_id::Int64
    lhs::Float64
    fromhistory::Bool
    children::Vector{Node}
    isconquered::Bool
    score::Float64
end

function BranchingGroup(candidate::AbstractBranchingCandidate, local_id::Int64, lhs::Float64)
    return BranchingGroup(candidate, local_id, lhs, false, Vector{Node}(), false, typemin(Float64))
end

setconquered!(group::BranchingGroup) = group.isconquered = true

get_lhs_distance_to_integer(group::BranchingGroup) = 
    min(group.lhs - floor(group.lhs), ceil(group.lhs) - group.lhs)    

function generate_children!(group::BranchingGroup, reform::Reformulation, parent::Node)
    group.children = generate_children(group.candidate, group.lhs, reform, parent)
    return
end

function regenerate_children!(group::BranchingGroup, reform::Reformulation, parent::Node)
    new_children = Vector{Node}()
    for child in group.children
        push!(new_children, Node(parent, child))
    end
    group.children = new_children
    return
end

function update_father_dual_bound!(group::BranchingGroup, parent::Node)
    isempty(group.children) && return

    worst_dual_bound = get_lp_dual_bound(getincumbents(group.children[1]))
    for (node_index, node) in enumerate(group.children)
        node_index == 1 && continue
        node_dual_bound = get_lp_dual_bound(getincumbents(node))
        if isbetter(worst_dual_bound, node_dual_bound)
            worst_dual_bound = node_dual_bound
        end
    end

    update_ip_dual_bound!(getincumbents(parent), worst_dual_bound)
    update_lp_dual_bound!(getincumbents(parent), worst_dual_bound)
    return
end

function compute_product_score!(group::BranchingGroup, parent_inc::Incumbents)
    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_inc)
    parent_delta = diff(get_ip_primal_bound(parent_inc), parent_lp_dual_bound)

    score::Float64 = 1.0
    all_branches_above_delta::Bool = true
    deltas = Vector{Float64}()
    for node in group.children
        node_delta = diff(get_lp_primal_bound(getincumbents(node)), parent_lp_dual_bound)
        if node_delta < parent_delta
            all_branches_above_delta = false
        end
        push!(deltas, node_delta)
    end

    if isempty(deltas)
        score = parent_delta * parent_delta
    elseif length(deltas) == 1
        score = parent_delta
    else
        sort!(deltas)
        for (delta_index, node_delta) in enumerate(deltas)
            if node_delta > parent_delta && (!all_branches_above_delta || delta_index > 2)
                node_delta = parent_delta
            end
            node_delta = max(node_delta, 1e-6) # TO DO : use tolerance here
            if (delta_index <= 2)
                score *= node_delta
            else
                score *= (node_delta / parent_delta)
            end
        end
    end
    group.score = score
    return
end

function number_of_leaves(gap::Float64, deltas::Vector{Float64})    
    inf::Float64 = 0.0
    sup::Float64 = 1e20
    mid::Float64 = 0.0
    for iteration = 1:100
        mid = (inf + sup) / 2.0
        if (sup - inf < sup / 1000000)
            break
        end    
        exp::Float64 = 0.0
        for delta in deltas
          exp += mid ^ (-delta / gap)
        end
        if (exp < 1.0)
          sup = mid
        else
          inf = mid
        end
        if (mid > 0.999e20)
          return -1
        end
    end
    return mid
end

function compute_tree_depth_score!(group::BranchingGroup, parent_inc::Incumbents)
    score::Float64 = 0.0
    
    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_inc)
    parent_delta = diff(get_ip_primal_bound(parent_inc), parent_lp_dual_bound)

    deltas = Vector{Float64}()
    nb_zero_deltas::Int64 = 0
    for node in group.children
        node_delta = diff(get_lp_primal_bound(getincumbents(node)), parent_lp_dual_bound)
        if node_delta < 1e-6 # TO DO : use tolerance here
            nb_zero_deltas += 1
        end
        if node_delta < parent_delta
            push!(deltas, max(node_delta, parent_delta * 1e-4))
        else
            push!(deltas, parent_delta)
        end
    end

    if isempty(deltas)
        score = 0.0
    elseif nb_zero_deltas == length(deltas)
        score = -Inf
    elseif length(deltas) == 1
        score = - parent_delta / deltas[1] 
    else
        score = - log(number_of_leaves(parent_delta, deltas)) / log(length(deltas))
    end

    group.score = score
    return
end

function print_bounds_and_score(group::BranchingGroup, phase_index::Int64, max_description_length::Int64)
    lengthdiff = max_description_length - length(getdescription(group.candidate))
    print("SB phase ", phase_index, " branch on ", getdescription(group.candidate))
    @printf " (lhs=%.4f)" group.lhs
    print(repeat(" ", lengthdiff), " : [")
    for (node_index, node) in enumerate(group.children)
        node_index > 1 && print(",")            
        @printf "%10.4f" getvalue(get_lp_primal_bound(getincumbents(node)))
    end
    @printf "], score = %10.4f\n" group.score
    return
end

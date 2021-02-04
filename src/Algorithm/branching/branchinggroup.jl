"""
    AbstractBranchingCandidate

    A branching candidate should contain all information needed to generate node's children    
    Branching candiates are also used to store the branching history. 
    History of a branching candidate is a collection of statistic records for every time this branching
        candidate was used to generate children nodes 
    Every branching candidate should contain a description, i.e. a string which serves for printing purposed,
    and also to detect the same branching candidates    
"""
abstract type AbstractBranchingCandidate end

getdescription(candidate::AbstractBranchingCandidate) = ""
generate_children!(
    candidate::AbstractBranchingCandidate, lhs::Float64, env::Env, data::ReformData, 
    node::Node
) = nothing

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

function BranchingGroup(
    candidate::AbstractBranchingCandidate, local_id::Int64, lhs::Float64
)
    return BranchingGroup(candidate, local_id, lhs, false, Vector{Node}(), false, typemin(Float64))
end

setconquered!(group::BranchingGroup) = group.isconquered = true

get_lhs_distance_to_integer(group::BranchingGroup) = 
    min(group.lhs - floor(group.lhs), ceil(group.lhs) - group.lhs)    

function generate_children!(
    group::BranchingGroup, env::Env, data::ReformData, parent::Node
)
    group.children = generate_children(group.candidate, group.lhs, env, data, parent)
    return
end

function regenerate_children!(group::BranchingGroup, parent::Node)
    new_children = Vector{Node}()
    for child in group.children
        push!(new_children, Node(parent, child))
    end
    group.children = new_children
    return
end

function compute_product_score!(group::BranchingGroup, parent_optstate::OptimizationState)
    parent_inc = getincumbents(parent_optstate)
    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_inc)
    parent_delta = diff(get_ip_primal_bound(parent_inc), parent_lp_dual_bound)

    score::Float64 = 1.0
    all_branches_above_delta::Bool = true
    deltas = Vector{Float64}()
    for node in group.children
        node_delta = diff(get_lp_primal_bound(getoptstate(node)), parent_lp_dual_bound)
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

function compute_tree_depth_score!(group::BranchingGroup, parent_optstate::OptimizationState)
    parent_inc = getincumbents(parent_optstate)
    score::Float64 = 0.0
    
    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_inc)
    parent_delta = diff(get_ip_primal_bound(parent_inc), parent_lp_dual_bound)

    deltas = Vector{Float64}()
    nb_zero_deltas::Int64 = 0
    for node in group.children
        node_delta = diff(get_lp_primal_bound(getoptstate(node)), parent_lp_dual_bound)
        if node_delta < 1e-6 # TO DO : use tolerance here
            nb_zero_deltas += 1
        end
        push!(deltas, min(parent_delta, node_delta))
    end

    max_delta = maximum(deltas)
    if nb_zero_deltas < length(deltas) && parent_delta > max_delta * 30
        parent_delta = max_delta * 30
    end

    if isempty(deltas)
        score = 0.0
    elseif nb_zero_deltas == length(deltas)
        score = -Inf
    elseif length(deltas) == 1
        score = - parent_delta / deltas[1] 
    else
        numleaves = number_of_leaves(parent_delta, deltas)
        if numleaves < 0
            score = - Inf
        else
            score = - log(numleaves) / log(length(deltas))
        end
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
        @printf "%10.4f" getvalue(get_lp_primal_bound(getoptstate(node)))
    end
    @printf "], score = %10.4f\n" group.score
    return
end

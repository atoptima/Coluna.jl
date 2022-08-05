############################################################################################
# Branching Candidates
############################################################################################

"""
A branching candidate is a data structure that contain all information needed to generate
children of a node.
"""
abstract type AbstractBranchingCandidate end

"""
    getdescription(branching_candidate)

Returns a string which serves to print the branching rule in the logs.
"""
getdescription(candidate::AbstractBranchingCandidate) = 
    error("getdescription not defined for branching candidates of type $(typeof(candidate)).")

"""
    generate_children!(branching_candidate, lhs, env, reform, node)

This method generates the children of a node described by `branching_candidate`.
"""
generate_children!(
    candidate::AbstractBranchingCandidate, ::Float64, ::Env, ::Reformulation, ::Node
) = error("generate_children not defined for branching candidates of type $(typeof(candidate)).")

############################################################################################
# Branching Group
############################################################################################

"""
A branching group is the union of a branching candidate and additional information that are
computed during the execution of the branching algorithm (TODO : which one ?).
"""
mutable struct BranchingGroup
    candidate::AbstractBranchingCandidate # the left-hand side in general.
    local_id::Int64
    lhs::Float64
    children::Vector{SbNode}
    isconquered::Bool
    score::Float64
end

function BranchingGroup(
    candidate::AbstractBranchingCandidate, local_id::Int64, lhs::Float64
)
    return BranchingGroup(candidate, local_id, lhs, SbNode[], false, typemin(Float64))
end

get_lhs_distance_to_integer(group::BranchingGroup) = 
    min(group.lhs - floor(group.lhs), ceil(group.lhs) - group.lhs)

function generate_children!(
    group::BranchingGroup, env::Env, reform::Reformulation, parent::Node
)
    group.children = generate_children(group.candidate, group.lhs, env, reform, parent)
    return
end

# TODO : it does not look like a regeneration but more like a new vector where we
# reassign children
function regenerate_children!(group::BranchingGroup, parent::Node)
    new_children = SbNode[]
    for child in group.children
        push!(new_children, SbNode(parent, child))
    end
    group.children = new_children
    return
end

# TODO : this method needs code documentation & context
function product_score(group::BranchingGroup, parent_optstate::OptimizationState)
    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_optstate)
    parent_delta = diff(get_ip_primal_bound(parent_optstate), parent_lp_dual_bound)

    all_branches_above_delta = true
    deltas = zeros(Float64, length(group.children))
    for (i, node) in enumerate(group.children)
        node_delta = diff(get_lp_primal_bound(getoptstate(node)), parent_lp_dual_bound)
        if node_delta < parent_delta
            all_branches_above_delta = false
        end
        deltas[i] = node_delta
    end

    score = 1.0
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
                score *= node_delta / parent_delta
            end
        end
    end
    return score
end

# TODO : this method needs code documentation & context
function number_of_leaves(gap::Float64, deltas::Vector{Float64})    
    inf::Float64 = 0.0
    sup::Float64 = 1e20
    mid::Float64 = 0.0
    for _ in 1:100
        mid = (inf + sup) / 2.0
        if sup - inf < sup / 1000000
            break
        end    
        exp::Float64 = 0.0
        for delta in deltas
            exp += mid^(-delta / gap)
        end
        if exp < 1.0
            sup = mid
        else
            inf = mid
        end
        if mid > 0.999e20
            return -1
        end
    end
    return mid
end

# TODO : this method needs code documentation & context
function tree_depth_score(group::BranchingGroup, parent_optstate::OptimizationState)
    if length(group.children) == 0
        return 0.0
    end

    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_optstate)
    parent_delta = diff(get_ip_primal_bound(parent_optstate), parent_lp_dual_bound)

    deltas = zeros(Float64, length(group.children))
    nb_zero_deltas = 0
    for (i, node) in enumerate(group.children)
        node_delta = diff(get_lp_primal_bound(getoptstate(node)), parent_lp_dual_bound)
        if node_delta < 1e-6 # TO DO : use tolerance here
            nb_zero_deltas += 1
        end
        deltas[i] = min(parent_delta, node_delta)
    end

    max_delta = maximum(deltas)
    if nb_zero_deltas < length(deltas) && parent_delta > max_delta * 30
        parent_delta = max_delta * 30
    end

    score = 0.0
    if nb_zero_deltas == length(deltas)
        score = -Inf
    elseif length(deltas) == 1
        score = -parent_delta / deltas[1] 
    else
        numleaves = number_of_leaves(parent_delta, deltas)
        if numleaves < 0
            score = -Inf
        else
            score = -log(numleaves) / log(length(deltas))
        end
    end
    return score
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

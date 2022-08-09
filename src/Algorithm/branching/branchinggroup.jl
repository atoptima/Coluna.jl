#######################################################################################
# Branching Group
############################################################################################


# TODO : this method needs code documentation & context
# TODO : unit tests
function product_score(children::Vector{SbNode}, parent_optstate::OptimizationState)
    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_optstate)
    parent_delta = diff(get_ip_primal_bound(parent_optstate), parent_lp_dual_bound)

    all_branches_above_delta = true
    deltas = zeros(Float64, length(children))
    for (i, node) in enumerate(children)
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
# TODO ; unit tests
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
# TODO : this method needs unit tests
function tree_depth_score(children::Vector{SbNode}, parent_optstate::OptimizationState)
    if iszero(length(children))
        return 0.0
    end

    # TO DO : we need to mesure the gap to the cut-off value
    parent_lp_dual_bound = get_lp_dual_bound(parent_optstate)
    parent_delta = diff(get_ip_primal_bound(parent_optstate), parent_lp_dual_bound)

    deltas = zeros(Float64, length(children))
    nb_zero_deltas = 0
    for (i, node) in enumerate(children)
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

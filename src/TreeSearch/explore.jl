"Generic implementation of the tree search algorithm for a given explore strategy."
@mustimplement "TreeSearch" tree_search(s::AbstractExploreStrategy, space, env, input) = nothing


################################################################################
# Depth First Strategy
################################################################################

"""
Explore the tree search space with a depth-first strategy.
The next visited node is the last one pushed in the stack of unexplored nodes.
"""
struct DepthFirstStrategy <: AbstractExploreStrategy end

function tree_search(::DepthFirstStrategy, space, env, input)
    root_node = new_root(space, input)
    stack = Stack{typeof(root_node)}()
    push!(stack, root_node)
    while !isempty(stack) && !stop(space, stack)
        current = pop!(stack)
        for child in children(space, current, env, stack)
            push!(stack, child)
        end
    end
    return TreeSearch.tree_search_output(space, stack)
end

################################################################################
# Best First Strategy
################################################################################

abstract type AbstractBestFirstSearch <: AbstractExploreStrategy end

"""
Explore the tree search space with a best-first strategy.
The next visited node is the one with the highest local dual bound.
"""
struct BestDualBoundStrategy <: AbstractBestFirstSearch end

function tree_search(strategy::AbstractBestFirstSearch, space, env, input)
    root_node = new_root(space, input)
    pq = PriorityQueue{typeof(root_node), Float64}()
    enqueue!(pq, root_node, get_priority(strategy, root_node))
    while !isempty(pq) && !stop(space, pq)
        current = dequeue!(pq)
        for child in children(space, current, env, pq)
            enqueue!(pq, child, get_priority(strategy, child))
        end
    end
    return TreeSearch.tree_search_output(space, pq)
end

################################################################################
# Limited Discrepancy
################################################################################

struct LimitedDiscrepancyStrategy <: AbstractExploreStrategy
    max_discrepancy::Int
end

struct LimitedDiscrepancySpace <: AbstractSearchSpace
    inner_space::AbstractSearchSpace
    max_discrepancy::Int
end
struct LimitedDiscrepancyNode
    inner_node::AbstractNode
    discrepancy::Int
end

new_root(space::LimitedDiscrepancySpace, input) = LimitedDiscrepancyNode(new_root(space.inner_space, input), space.max_discrepancy)
stop(space::LimitedDiscrepancySpace, nodes) = stop(space.inner_space, nodes)
tree_search_output(space::LimitedDiscrepancySpace, nodes) = tree_search_output(space.inner_space, nodes)

function children(space::LimitedDiscrepancySpace, current::LimitedDiscrepancyNode, env, input)
    lds_children = LimitedDiscrepancyNode[]
    inner_children = children(space.inner_space, current.inner_node, env, input)
    for (i, child) in enumerate(inner_children)
        discrepancy = current.discrepancy - i + 1
        if discrepancy < 0
            break
        end
        pushfirst!(lds_children, LimitedDiscrepancyNode(child, discrepancy))
    end
    return lds_children
end

function tree_search(strategy::LimitedDiscrepancyStrategy, space, env, input)
    space = LimitedDiscrepancySpace(space, strategy.max_discrepancy)
    return tree_search(DepthFirstStrategy(), space, env, input)
end
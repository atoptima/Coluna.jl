struct DepthFirstExploreStrategy <: AbstractExploreStrategy end
struct BestFirstSearch <: AbstractExploreStrategy end

function tree_search(::DepthFirstExploreStrategy, space, env)
    root_node = new_root(space)
    stack = Stack{typeof(root_node)}()
    push!(stack, root_node)
    while !isempty(stack) # and stopping criterion
        current = pop!(stack)
        for child in children(space, current, env)
            push!(stack, child)
        end
    end
    return tree_search_output(space)
end

function tree_search(strategy::BestFirstSearch, space, env)
    root_node = new_root(space)
    pq = PriorityQueue{typeof(root_node), Float64}()
    enqueue!(pq, root_node, priority(strategy, root_node))
    while !isempty(pq) # and stopping criterion
        current = dequeue!(pq)
        for child in children(space, current, env)
            enqueue!(pq, child, priority(strategy, child))
        end
    end
    return tree_search_output(space)
end
struct DepthFirstExploreStrategy <: AbstractExploreStrategy end

struct BreadthFirstSearch <: AbstractExploreStrategy end

function tree_search(strategy::DepthFirstExploreStrategy, space::AbstractSearchSpace)
    tracker = new_tracker(space, strategy)
    root_node = new_root(space, tracker)
    stack = Stack{typeof(root_node)}()
    push!(stack, root_node)
    while !isempty(stack) # and stopping criterion
        current = pop!(stack)
        # conquer
        # register solution in manager.
        for child in new_children(strategy, current, space, tracker)
            push!(stack, child)
        end
    end
end

function tree_search(strategy::BreadthFirstSearch, space::AbstractSearchSpace)
    tracker = new_tracker(space, strategy)
    root_node = new_root(space, tracker)
    pq = PriorityQueue{typeof(root_node), Float64}()
    enqueue!(pq, root_node, cost(strategy, root_node))
    while !isempty(pq) # and stopping criterion
        current = dequeue!(pq)
        # conquer
        # register solution in manager
        for child in new_children(strategy, current, space, tracker)
            enqueue!(pq, child, cost(strategy, child))
        end
    end
end
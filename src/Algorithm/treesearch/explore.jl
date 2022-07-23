struct DepthFirstExploreStrategy <: AbstractExploreStrategy end

struct BreadthFirstSearch <: AbstractExploreStrategy end

function children_from_divide(divide, node, space, tracker, env)
    reform = get_reformulation(divide, space)
    input = get_input(divide, space, node, tracker)
    branches = run!(divide, env, reform, input)
    return new_children(branches, divide, node, space, tracker)
end

function tree_search(strategy::DepthFirstExploreStrategy, conquer, divide, space, env)
    tracker = new_tracker(space, strategy)
    root_node = new_root(space, tracker)
    stack = Stack{typeof(root_node)}()
    push!(stack, root_node)
    previous = nothing
    while !isempty(stack) # and stopping criterion
        current = pop!(stack)
        if !isnothing(previous)
            node_change!(previous, current, space, tracker)
        end
        reform = get_reformulation(conquer, space)
        input = get_input(conquer, space, current, tracker)
        output = run!(conquer, env, reform, input)
        after_conquer!(space, output)
        for child in children_from_divide(divide, current, space, tracker, env)
            push!(stack, child)
        end
        previous = current
    end
    return tree_search_output(space)
end

function tree_search(strategy::BreadthFirstSearch, conquer, divide, space, env)
    tracker = new_tracker(space, strategy)
    root_node = new_root(space, tracker)
    pq = PriorityQueue{typeof(root_node), Float64}()
    enqueue!(pq, root_node, priority(strategy, root_node))
    previous = nothing
    while !isempty(pq) # and stopping criterion
        current = dequeue!(pq)
        if !isnothing(previous)
            node_change!(previous, current, space, tracker)
        end
        reform = get_reformulation(conquer, space)
        input = get_input(conquer, space, node, tracker)
        output = run!(conquer, env, reform, input)
        after_conquer!(space, output)
        for child in children_from_divide(divide, current, space, tracker, env)
            enqueue!(pq, child, priority(strategy, child))
        end
        previous = current
    end
    return tree_search_output(space)
end
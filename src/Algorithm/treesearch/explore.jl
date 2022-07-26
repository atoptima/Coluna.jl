struct DepthFirstExploreStrategy <: AbstractExploreStrategy end
struct BreadthFirstSearch <: AbstractExploreStrategy end

# TODO: use a search space specific to Coluna's Tree Search.
function children(space::AbstractSearchSpace, node, env)
    reform = get_reformulation(space)
    conquer_alg = get_conquer(space)
    conquer_input = get_input(conquer_alg, space, node)
    conquer_output = run!(conquer_alg, env, reform, conquer_input)
    after_conquer!(space, conquer_output)
    divide_alg = get_divide(space)
    divide_input = get_input(divide_alg, space, node)
    branches = run!(divide_alg, env, reform, divide_input)
    return new_children(space, branches, node)
end

function tree_search(strategy::DepthFirstExploreStrategy, space, env)
    root_node = new_root(space)
    stack = Stack{typeof(root_node)}()
    push!(stack, root_node)
    previous = nothing
    while !isempty(stack) # and stopping criterion
        current = pop!(stack)
        if !isnothing(previous)
            node_change!(previous, current, space)
        end
        for child in children(space, current, env)
            push!(stack, child)
        end
        previous = current
    end
    return tree_search_output(space)
end

function tree_search(strategy::BreadthFirstSearch, space, env)
    root_node = new_root(space)
    pq = PriorityQueue{typeof(root_node), Float64}()
    enqueue!(pq, root_node, priority(strategy, root_node))
    previous = nothing
    while !isempty(pq) # and stopping criterion
        current = dequeue!(pq)
        if !isnothing(previous)
            node_change!(previous, current, space)
        end
        for child in children(space, current, env)
            enqueue!(pq, child, priority(strategy, child))
        end
        previous = current
    end
    return tree_search_output(space)
end
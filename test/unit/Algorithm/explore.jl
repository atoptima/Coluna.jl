struct NodeAe1 <: ClA.AbstractNode
    id::Int
    depth::Int
    parent::Union{Nothing, NodeAe1}

    function NodeAe1(id::Int, parent::Union{Nothing, NodeAe1} = nothing)
        depth = isnothing(parent) ? 0 : parent.depth + 1
        return new(id, depth, parent)
    end
end

ClA.get_root(node::NodeAe1) = isnothing(node.parent) ? node : ClA.root(node.parent)

mutable struct CustomSearchSpaceAe1 <: ClA.AbstractSearchSpace
    nb_branches::Int
    max_depth::Int
    max_nb_of_nodes::Int
    nb_nodes_generated::Int
    visit_order::Vector{Int}

    function CustomSearchSpaceAe1(nb_branches::Int, max_depth::Int, max_nb_of_nodes::Int)
        return new(nb_branches, max_depth, max_nb_of_nodes, 0, [])
    end
end

function ClA.new_root(space::CustomSearchSpaceAe1, input)
    space.nb_nodes_generated += 1
    return NodeAe1(1)
end

ClA.stop(sp::CustomSearchSpaceAe1) = false

struct CustomBestFirstSearch <: ClA.AbstractBestFirstSearch end

function ClA.get_priority(::CustomBestFirstSearch, node::NodeAe1)
    node.id == 1 && return 0
    if iseven(node.parent.id) && !iseven(node.id) || 
        iseven(node.id) && !iseven(node.parent.id)
        return -node.id
    end
    return -node.depth
end

function print_node(current)
    t = repeat("   ", current.depth)
    node = string("NodeAe1 ", current.id)
    println(t, node)
end

function ClA.children(space::CustomSearchSpaceAe1, current, _, _)
    print_node(current)
    children = NodeAe1[]
    push!(space.visit_order, current.id)
    if current.depth != space.max_depth &&
        space.nb_nodes_generated + space.nb_branches <= space.max_nb_of_nodes 
        for _ in 1:space.nb_branches
            space.nb_nodes_generated += 1
            node_id = space.nb_nodes_generated
            child = NodeAe1(node_id, current)
            push!(children, child)
        end
    end
    return children
end

ClA.tree_search_output(space::CustomSearchSpaceAe1, _) = space.visit_order

@testset "Algorithm - treesearch exploration" begin
    @testset "Depth-First Search" begin
        search_space = CustomSearchSpaceAe1(2, 3, 11)
        visit_order = ClA.tree_search(ClA.DepthFirstStrategy(), search_space, nothing, nothing)
        @show visit_order
        @test visit_order == [1, 3, 5, 7, 6, 4, 9, 8, 2, 11, 10]
    end

    @testset "Best-First Search" begin
        search_space = CustomSearchSpaceAe1(2, 3, 11)
        visit_order = ClA.tree_search(CustomBestFirstSearch(), search_space, nothing, nothing)
        @show visit_order
        @test visit_order == [1, 2, 5, 6, 7, 4, 9, 8, 3, 10, 11]
    end
end

struct NodeAe1 <: Coluna.TreeSearch.AbstractNode
    id::Int
    depth::Int
    parent::Union{Nothing, NodeAe1}

    function NodeAe1(id::Int, parent::Union{Nothing, NodeAe1} = nothing)
        depth = isnothing(parent) ? 0 : parent.depth + 1
        return new(id, depth, parent)
    end
end

Coluna.TreeSearch.get_root(node::NodeAe1) = isnothing(node.parent) ? node : ClA.root(node.parent)

mutable struct CustomSearchSpaceAe1 <: Coluna.TreeSearch.AbstractSearchSpace
    nb_branches::Int
    max_depth::Int
    max_nb_of_nodes::Int
    nb_nodes_generated::Int
    visit_order::Vector{Int}

    function CustomSearchSpaceAe1(nb_branches::Int, max_depth::Int, max_nb_of_nodes::Int)
        return new(nb_branches, max_depth, max_nb_of_nodes, 0, [])
    end
end

function Coluna.TreeSearch.new_root(space::CustomSearchSpaceAe1, input)
    space.nb_nodes_generated += 1
    return NodeAe1(1)
end

Coluna.TreeSearch.stop(sp::CustomSearchSpaceAe1, _) = false

struct CustomBestFirstSearch <: Coluna.TreeSearch.AbstractBestFirstSearch end

Coluna.TreeSearch.get_priority(::CustomBestFirstSearch, node::NodeAe1) = -node.id

function Coluna.TreeSearch.children(space::CustomSearchSpaceAe1, current, _, _)
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

Coluna.TreeSearch.tree_search_output(space::CustomSearchSpaceAe1, _) = space.visit_order

function test_dfs()
    search_space = CustomSearchSpaceAe1(2, 3, 11)
    visit_order = Coluna.TreeSearch.tree_search(Coluna.TreeSearch.DepthFirstStrategy(), search_space, nothing, nothing)
    @test visit_order == [1, 3, 5, 7, 6, 4, 9, 8, 2, 11, 10]
    return
end
register!(unit_tests, "explore", test_dfs)


function test_bfs()
    search_space = CustomSearchSpaceAe1(2, 3, 11)
    visit_order = Coluna.TreeSearch.tree_search(CustomBestFirstSearch(), search_space, nothing, nothing)
    @test visit_order == [1, 3, 5, 7, 6, 4, 9, 8, 2, 11, 10]
end
register!(unit_tests, "explore", test_bfs)

############################################################################################
# Limited Discrepancy Explore Strategy
############################################################################################

struct NodeAe2 <: Coluna.TreeSearch.AbstractNode
    id::Int
    depth::Int
    parent::Union{Nothing, NodeAe2}

    function NodeAe2(id::Int, parent::Union{Nothing, NodeAe2} = nothing)
        depth = isnothing(parent) ? 0 : parent.depth + 1
        return new(id, depth, parent)
    end
end

Coluna.TreeSearch.get_root(node::NodeAe2) = isnothing(node.parent) ? node : ClA.root(node.parent)

mutable struct CustomSearchSpaceAe2 <: Coluna.TreeSearch.AbstractSearchSpace
    nb_branches::Int
    max_depth::Int
    nb_nodes_generated::Int
    visit_order::Vector{Int}

    function CustomSearchSpaceAe2(nb_branches::Int, max_depth::Int)
        return new(nb_branches, max_depth, 0, Int[])
    end
end

function Coluna.TreeSearch.new_root(space::CustomSearchSpaceAe2, input)
    space.nb_nodes_generated += 1
    return NodeAe2(1)
end

Coluna.TreeSearch.stop(sp::CustomSearchSpaceAe2, _) = false

function Coluna.TreeSearch.children(space::CustomSearchSpaceAe2, current, _, _)
    children = NodeAe2[]
    push!(space.visit_order, current.id)
    if current.depth != space.max_depth
        for _ in 1:space.nb_branches
            space.nb_nodes_generated += 1
            node_id = space.nb_nodes_generated
            child = NodeAe2(node_id, current)
            push!(children, child)
        end
    end
    return children
end

Coluna.TreeSearch.tree_search_output(space::CustomSearchSpaceAe2, _) = space.visit_order


function test_lds()
    # max_depth = 3, max_discrepancy = 2
    #
    # 01------------------------------------------
    # 02--------------------     12----------    18      
    # 03------   07---    10     13---    16     19
    # 04 05 06   08 09    11     14 15    17     20

    # =============================================

    #  1*
    #  --------------------------------------------------------------------------------------
    #  2*                                   3*                                      4*
    #  --------------------------------     ----------------------------------      ------------------------------
    #  5*         6*          7*            17*           18*           19          26*         27         28   
    #  8* 9* 10*  11* 12* 13  14* 15 16     20* 21* 22    23*  24 25                29* 30 31    


    search_space = CustomSearchSpaceAe2(3, 3)
    visit_order = Coluna.TreeSearch.tree_search(Coluna.TreeSearch.LimitedDiscrepancyStrategy(2), search_space, nothing, nothing)

    @test visit_order == [1, 2, 5, 8, 9, 10, 6, 11, 12, 7, 14, 3, 17, 20, 21, 18, 23, 4, 26, 29]
    @test length(visit_order) == 20
end
register!(unit_tests, "explore", test_lds)

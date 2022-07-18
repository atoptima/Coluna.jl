# Ati = Algorithm/treesearch/interface.jl  

# In this test, we consider a minimization problem with three binary variables.
# Costs of the variable are [-1, 1, -2].
# The problem has no additional constraints. Therefore, the optimal solution is [1, 0, 1].

# Branching strategy:
# if no branching constraint, the value of each variable is 0.5.
# depth 0: branch on first variable
# depth 1: branch on second variable
# depth 2: branch on third variable

const NB_VARIABLES_ATI1 = 3

mutable struct TrackerAti1 <: ClA.AbstractTracker
    node_counter::Int
    node_to_var_ubs::Dict{Int, Vector{Int}}
    node_to_var_lbs::Dict{Int, Vector{Int}}

    function TrackerAti1()
        node_to_var_ubs = Dict{Int, Vector{Int}}()
        node_to_var_lbs = Dict{Int, Vector{Int}}()
        return new(0, node_to_var_ubs, node_to_var_lbs)
    end
end

struct SearchSpaceAti1 <: ClA.AbstractSearchSpace
    var_domains::Vector{Tuple{Int,Int}}
    SearchSpaceAti1() = new(fill((0,1), NB_VARIABLES_ATI1))
end

struct NodeAti1 <: ClA.AbstractNode
    uid::Int
    depth::Int
    fixed_var_index::Union{Nothing,Int}
    fixed_var_value::Union{Nothing,Float64}
    solution::Vector{Float64}
    children::Vector{NodeAti1}
    function NodeAti1(
        tracker::TrackerAti1, 
        parent::Union{Nothing, NodeAti1} = nothing,
        var_index::Union{Nothing,Int} = nothing,
        var_value::Union{Nothing,Real} = 0
    )
        @assert isnothing(var_index) || 1 <= var_index <= NB_VARIABLES_ATI1
        depth = isnothing(parent) ? 0 : parent.depth + 1
        solution = if isnothing(parent)
            fill(0.5, NB_VARIABLES_ATI1)
        else
            sol = copy(parent.solution)
            sol[var_index] = var_value
            sol
        end
        return new(tracker.node_counter += 1, depth, var_index, var_value, solution, NodeAti1[])
    end
end

ClA.new_root(::SearchSpaceAti1, tracker::TrackerAti1) = NodeAti1(tracker)

ClA.new_tracker(::SearchSpaceAti1, ::ClA.AbstractExploreStrategy) = TrackerAti1()

function ClA.new_children(::ClA.AbstractExploreStrategy, node, space, tracker)
    var_index = node.depth + 1
    if var_index > NB_VARIABLES_ATI1
        return NodeAti1[]
    end
    child1 = NodeAti1(tracker, node, var_index, 0.0)
    child2 = NodeAti1(tracker, node, var_index, 1.0)
    push!(node.children, child1, child2)
    return [child1, child2]
end

ClA.root(node::NodeAti1) = isnothing(node.parent) ? node : ClA.root(node.parent)
ClA.parent(node::NodeAti1) = node.parent
ClA.children(node::NodeAti1) = node.children

# TODO
ClA.delete_node(node::NodeAti1, tracker::TrackerAti1) = nothing
ClA.manager(space::SearchSpaceAti1) = nothing
ClA.inner_space(space::SearchSpaceAti1) = nothing

@testset "Algorithm - treesearch interface" begin
    space = SearchSpaceAti1()
    @show space
    ClA.tree_search(ClA.DepthFirstExploreStrategy(), space)
end
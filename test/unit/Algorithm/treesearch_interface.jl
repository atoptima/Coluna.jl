using Parameters

# # Tutorial for the tree search interface
# ## Introduction

# This is a test (and also a tutorial) on how to use the tree search interface together with
# algorithms.
#
# We consider a minimization problem with four binary variables
# Costs of the variable are `[-1, 1, 1, 1]``.
# The problem has no additional constraints. 
# Therefore, the optimal solution is `[1, 0, 0, 0]`.

const NB_VARIABLES_ATI1 = 4

struct FormulationAti1 <: ClB.AbstractModel
    var_cost::Vector{Int}
    var_domains::Vector{Tuple{Int,Int}}
    FormulationAti1() = new([-1, 1, 1, 1], fill((0,1), NB_VARIABLES_ATI1))
end

# We are going to enumerate all possible values for the two first variables using
# a binary tree : 
#  - depth 0: branch on first variable
#  - depth 1: branch on second variable
#
# When the three first variables are fixed, we dive by fixing the fourth and the fifth
# variables to zero.
#
# At the end, the tree will look like:
#
# ```mermaid
#  graph TD
#    A0(root node) -->|x1 >= 1| A1
#  	 A0 -->|x1 <= 0| B1
# 	 A1 -->|x2 <= 0| A2
# 	 A1 -->|x2 >= 1| B2
# 	 B1 -->|x2 <= 0| C2
# 	 B1 -->|x2 >= 1| D2
# 	 A2 -->|x3 == 0| A3
# 	 B2 -->|x3 == 0| B3
# 	 C2 -->|x3 == 0| C3
# 	 D2 -->|x3 == 0| D3
# 	 A3 -->|x4 == 0| A4
# 	 B3 -->|x4 == 0| B4
# 	 C3 -->|x4 == 0| C4
# 	 D3 -->|x4 == 0| D4
# 	 style A3 stroke:red
# 	 style A4 stroke:red
# 	 style B3 stroke:red
# 	 style B4 stroke:red
# 	 style C3 stroke:red
# 	 style C4 stroke:red
# 	 style D3 stroke:red
# 	 style D4 stroke:red
# ```

# ## Tree search data structures

# Now, we define the four concepts we'll use in the tree search algorithms.
# We start by defining the search space of the binary tree and the diving algorithms.

struct BtSearchSpaceAti1 <: ClA.AbstractSearchSpace
    formulation::FormulationAti1
end

struct DivingSearchSpaceAti1 <: ClA.AbstractSearchSpace
    formulation::FormulationAti1
    starting_node_in_bt::ClA.AbstractNode # change node
end

# Then, we define the tracker that will store data for each node of the tree.
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

# At last, we define the data contained in a node.
struct NodeAti1 <: ClA.AbstractNode
    uid::Int
    depth::Int
    fixed_var_index::Union{Nothing, Int}
    fixed_var_value::Union{Nothing, Float64}
    solution::Vector{Float64}
    parent::Union{Nothing, NodeAti1}
    function NodeAti1(
        tracker::TrackerAti1, 
        parent::Union{Nothing, NodeAti1} = nothing,
        var_index::Union{Nothing,Int} = nothing,
        var_value::Union{Nothing,Real} = 0
    )
        @assert isnothing(var_index) || 1 <= var_index <= NB_VARIABLES_ATI1
        node_id = tracker.node_counter += 1
        depth = isnothing(parent) ? 0 : parent.depth + 1
        # Store the solution at this node.
        solution = if isnothing(parent)
            fill(0.5, NB_VARIABLES_ATI1)
        else
            sol = copy(parent.solution)
            if !isnothing(var_index)
                sol[var_index] = var_value
            end
            sol
        end
        # Store the state of the formulation at this node into the tracker.
        tracker.node_to_var_lbs[node_id] = map(var_val -> var_val == 0.5 ? 0 : var_val, solution)
        tracker.node_to_var_ubs[node_id] = map(var_val -> var_val == 0.5 ? 1 : var_val, solution)
        return new(
            node_id,
            depth,
            var_index,
            var_value,
            solution,
            parent
        )
    end
end

ClA.uid(node::NodeAti1) = node.uid

# ## Algorithms

# Let's define the algorithm that we will use:
# At each node, we define an algorithm `ComputeSolCostAti1` that compute the cost of the
# solution and returns its value.

@with_kw struct ComputeSolCostAti1 <: ClA.AbstractAlgorithm 
    log::String = "compute solution cost"
end

struct BtInputAti1
    current_node::NodeAti1
end

struct DivideInputAti1 
    current_node::NodeAti1
end

struct DivingInputAti1
    starting_node_in_parent_algorithm
end

function ClA.run!(algo::ComputeSolCostAti1, env, model::FormulationAti1, input::BtInputAti1)
    println("== $(algo.log) [node $(input.current_node.uid)] ==")
    @show model.var_domains
    sol_cost = 0.0
    for (cost, (ub, lb)) in Iterators.zip(model.var_cost, model.var_domains)
        var_val = ub == lb ? ub : 0.5
        sol_cost += var_val * cost
    end
    return sol_cost
end

# To generate, the children, we create an algorithm named `DivideAti1` that will create,
# for a given variable x, both branches x <= 0 & x >= 1 or only branch x = 0 depending on
# parameters chosen.
@with_kw struct DivideAti1 <: ClA.AbstractAlgorithm
    log::String = "classic divide"
    create_both_branches::Bool = true
end

function ClA.run!(algo::DivideAti1, env, model::FormulationAti1, input::DivideInputAti1)
    println(algo.log)
    parent = input.current_node
    if algo.create_both_branches && parent.depth < 3
        var_pos_to_branch_in = parent.depth + 1
        var_pos_to_branch_in > 4 && return []
        println("** branch on x$(var_pos_to_branch_in) == 0 & x$(var_pos_to_branch_in) == 1")
        return [(var_pos_to_branch_in, 0), (var_pos_to_branch_in, 1)]
    elseif !algo.create_both_branches
        var_pos_to_branch_in = parent.depth
        var_pos_to_branch_in > 4 && return []
        println("** branch on x$(var_pos_to_branch_in) == 0")
        return [(var_pos_to_branch_in, 0)]
    end
    return []
end

# The diving is a tree search algorithm that uses:
#  - `ComputeSolCostAti1` as conquer strategy
#  - `DivideAti1` with parameter `create_both_branches` equals to `false` as divide strategy
#  - `Coluna.Algorithm.DepthFirstExploreStrategy` as explore strategy

# We define the algorithm that will be used at each node of the diving algorithm.
@with_kw struct DivingConquerAti1 <: ClA.AbstractAlgorithm
    compute = ComputeSolCostAti1(log="compute solution cost of Diving tree")
end

function ClA.run!(algo::DivingConquerAti1, env, model, input::DivideInputAti1)
    input = BtInputAti1(input.current_node)
    return run!(algo.compute, env, model, input) # TODO interface to change the input ?
end

@with_kw struct DivingAti1 <: ClA.AbstractAlgorithm
    conquer = DivingConquerAti1()
    divide = DivideAti1(
        log = "divide for diving",
        create_both_branches = false
    )
    explore = ClA.DepthFirstExploreStrategy()
end

function ClA.run!(algo::DivingAti1, env, model::FormulationAti1, input::DivingInputAti1)
    println("~~~~~~~~ Diving starts ~~~~~~~~")
    diving_space = ClA.new_space(algo.conquer, env, model, input)
    ClA.tree_search(algo.explore, algo.conquer, algo.divide, diving_space, env)
    println("~~~~~~~~ end of Diving ~~~~~~~~")
end

# We define the algorithm that will be used at each node of the binary tree algorithm.
# It runs the `ComputeSolCostAti1` algorithm and then the diving algorithm if the two first
# variables have been fixed.
@with_kw struct BtConquerAti1 <: ClA.AbstractAlgorithm
    compute = ComputeSolCostAti1(log = "compute solution cost for Binary tree")
    heuristic = DivingAti1()
end

function ClA.run!(algo::BtConquerAti1, env, model, input)
    output = run!(algo.compute, env, model, input)
    if input.current_node.depth == 2
        diving_input = DivingInputAti1(input.current_node) # TODO: needs an interface or specific to the algorithm ?
        diving_output = run!(algo.heuristic, env, model, diving_input)
    end
    return output 
end

# struct VisuForConquerSearchSpaceAti1 <: ClA.AbstractSearchSpace
#     conquer_space
# end

# @with_kw struct VisuForConquerAti1 
#     conquer = ComputeSolCostAti1()
# end

# function ClA.run!(algo::VisuForConquerAti1, env, model, input)
#     ClA.run!(algo.conquer, env, model, input)
# end


ClA.new_root(::BtSearchSpaceAti1, tracker::TrackerAti1) = NodeAti1(tracker)

function ClA.new_root(space::DivingSearchSpaceAti1, tracker::TrackerAti1)
    return NodeAti1(tracker, space.starting_node_in_bt)
end

ClA.new_tracker(::BtSearchSpaceAti1, ::ClA.AbstractExploreStrategy) = TrackerAti1()
ClA.new_tracker(space::DivingSearchSpaceAti1, strategy::ClA.AbstractExploreStrategy) = TrackerAti1()

function ClA.new_children(branches, divide::DivideAti1, node::NodeAti1, space::ClA.AbstractSearchSpace, tracker::ClA.AbstractTracker)
    children = NodeAti1[]
    for (var_pos, var_val_fixed) in branches
        child = NodeAti1(tracker, node, var_pos, var_val_fixed)
        push!(children, child)
    end
    return children
end

ClA.root(node::NodeAti1) = isnothing(node.parent) ? node : ClA.root(node.parent)
ClA.parent(node::NodeAti1) = node.parent

ClA.cost(::ClA.BreadthFirstSearch, node::NodeAti1) = -node.depth

# The conquer algorithm of the tree search defines the search space.
function ClA.new_space(::BtConquerAti1, env, model, input)
    @show input
    return BtSearchSpaceAti1(model)
end

function ClA.new_space(::DivingConquerAti1, env, model, input::DivingInputAti1)
    return DivingSearchSpaceAti1(model, input.starting_node_in_parent_algorithm)
end

function ClA.get_reformulation(::ClA.AbstractAlgorithm, space::ClA.AbstractSearchSpace)
    return space.formulation
end

ClA.get_input(::BtConquerAti1, space::BtSearchSpaceAti1, node::NodeAti1, tracker::TrackerAti1) = BtInputAti1(node) 
ClA.get_input(::DivideAti1, space::BtSearchSpaceAti1, node::NodeAti1, tracker::TrackerAti1) = DivideInputAti1(node)
ClA.get_input(::DivingConquerAti1, space::DivingSearchSpaceAti1, node::NodeAti1, tracker::TrackerAti1) = DivideInputAti1(node)
ClA.get_input(::DivideAti1, space::DivingSearchSpaceAti1, node::NodeAti1, tracker::TrackerAti1) = DivideInputAti1(node)

function ClA.node_change!(::NodeAti1, current::NodeAti1, space::ClA.AbstractSearchSpace, tracker::TrackerAti1)
    uid = ClA.uid(current)
    for (var_pos, bounds) in enumerate(Iterators.zip(tracker.node_to_var_lbs[uid], tracker.node_to_var_ubs[uid]))   
       space.formulation.var_domains[var_pos] = bounds 
    end
end

@testset "Algorithm - treesearch interface" begin
    # space = BtSearchSpaceAti1()
    # @show space
    #ClA.tree_search(ClA.DepthFirstExploreStrategy(), space)

    # println("**** 2 ****")
   # ClA.tree_search(ClA.BreadthFirstSearch(), space)

    println("\e[34m ***** 3 ***** \e[00m")

    env = nothing
    model = FormulationAti1()
    input = nothing

    treesearch = ClA.NewTreeSearchAlgorithm(
        conqueralg = BtConquerAti1(),
        dividealg = DivideAti1(),
        explorestrategy = ClA.DepthFirstExploreStrategy()
    )

    ClA.run!(treesearch, env, model, input)
    exit()
end

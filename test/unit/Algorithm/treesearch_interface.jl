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

const LOG_ATI1 = true
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
# When the two first variables are fixed, we dive to fix the third and the fourth
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

# Now, we define the two concepts we'll use in the tree search algorithms.
# The third concept is the explore strategy and implemented in Coluna (see explore.jl).
# We start by defining the search space of the binary tree and the diving algorithms.

mutable struct BtSearchSpaceAti1 <: ClA.AbstractColunaSearchSpace
    formulation::FormulationAti1
    cost_of_best_solution::Float64
    conquer_alg
    divide_alg
    previous
    BtSearchSpaceAti1(form, conquer, divide) = new(form, Inf, conquer, divide, nothing)
end

ClA.get_reformulation(sp::BtSearchSpaceAti1) = sp.formulation
ClA.get_conquer(sp::BtSearchSpaceAti1) = sp.conquer_alg
ClA.get_divide(sp::BtSearchSpaceAti1) = sp.divide_alg
ClA.get_previous(sp::BtSearchSpaceAti1) = sp.previous
ClA.set_previous!(sp::BtSearchSpaceAti1, previous) = sp.previous = previous
ClA.stop(sp::BtSearchSpaceAti1) = false

mutable struct DivingSearchSpaceAti1 <: ClA.AbstractColunaSearchSpace
    formulation::FormulationAti1
    starting_node_in_bt::ClA.AbstractNode # change node
    cost_of_best_solution::Float64
    conquer_alg
    divide_alg
    previous
    DivingSearchSpaceAti1(form, node, conquer, divide) = new(form, node, Inf, conquer, divide, nothing)
end

ClA.get_reformulation(sp::DivingSearchSpaceAti1) = sp.formulation
ClA.get_conquer(sp::DivingSearchSpaceAti1) = sp.conquer_alg
ClA.get_divide(sp::DivingSearchSpaceAti1) = sp.divide_alg
ClA.get_previous(sp::DivingSearchSpaceAti1) = sp.previous
ClA.set_previous!(sp::DivingSearchSpaceAti1, previous) = sp.previous = previous
ClA.stop(sp::DivingSearchSpaceAti1) = false

# At last, we define the data contained in a node.
struct NodeAti1 <: ClA.AbstractNode
    depth::Int
    fixed_var_index::Union{Nothing, Int}
    fixed_var_value::Union{Nothing, Float64}
    solution::Vector{Float64}
    var_lbs::Vector{Int}
    var_ubs::Vector{Int}
    parent::Union{Nothing, NodeAti1}
    function NodeAti1(
        parent::Union{Nothing, NodeAti1} = nothing,
        var_index::Union{Nothing,Int} = nothing,
        var_value::Union{Nothing,Real} = 0
    )
        @assert isnothing(var_index) || 1 <= var_index <= NB_VARIABLES_ATI1
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
        # Store the state of the formulation.
        var_lbs = map(var_val -> var_val == 0.5 ? 0 : var_val, solution)
        var_ubs = map(var_val -> var_val == 0.5 ? 1 : var_val, solution)
        return new(
            depth,
            var_index,
            var_value,
            solution,
            var_lbs,
            var_ubs,
            parent
        )
    end
end

ClA.get_root(node::NodeAti1) = isnothing(node.parent) ? node : ClA.root(node.parent)
ClA.get_parent(node::NodeAti1) = node.parent

# ## Algorithms

# Let's define the algorithm that we will use:
# At each node, we define an algorithm `ComputeSolCostAti1` that compute the cost of the
# solution and returns its value.

@with_kw struct ComputeSolCostAti1 <: ClA.AbstractAlgorithm 
    log::String = "compute solution cost"
end

struct ComputeSolCostInputAti1
    current_node::NodeAti1
end

function ClA.run!(algo::ComputeSolCostAti1, env, model::FormulationAti1, input::ComputeSolCostInputAti1)
    LOG_ATI1 && println("== $(algo.log) ==")
    LOG_ATI1 && @show model.var_domains
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

struct DivideInputAti1
    current_node::NodeAti1
end

function ClA.run!(algo::DivideAti1, env, ::FormulationAti1, input::DivideInputAti1)
    LOG_ATI1 && println(algo.log)
    parent = input.current_node
    if algo.create_both_branches && parent.depth < 2
        var_pos_to_branch_in = parent.depth + 1
        var_pos_to_branch_in > 4 && return []
        LOG_ATI1 && println("** branch on x$(var_pos_to_branch_in) == 0 & x$(var_pos_to_branch_in) == 1")
        return [(var_pos_to_branch_in, 0), (var_pos_to_branch_in, 1)]
    elseif !algo.create_both_branches
        var_pos_to_branch_in = parent.depth
        var_pos_to_branch_in > 4 && return []
        LOG_ATI1 && println("** branch on x$(var_pos_to_branch_in) == 0")
        return [(var_pos_to_branch_in, 0)]
    end
    return []
end

# The diving is a tree search algorithm that uses:
#  - `ComputeSolCostAti1` as conquer strategy
#  - `DivideAti1` with parameter `create_both_branches` equals to `false` as divide strategy
#  - `Coluna.Algorithm.DepthFirstStrategy` as explore strategy
@with_kw struct DivingAti1 <: ClA.AbstractAlgorithm
    conqueralg = ComputeSolCostAti1(log="compute solution cost of Diving tree")
    dividealg = DivideAti1(
        log = "divide for diving",
        create_both_branches = false
    )
    explore = ClA.DepthFirstStrategy()
end

struct DivingInputAti1
    starting_node_in_parent_algorithm
end

function ClA.run!(algo::DivingAti1, env, model::FormulationAti1, input::DivingInputAti1)
    LOG_ATI1 && println("~~~~~~~~ Diving starts ~~~~~~~~")
    diving_space = ClA.new_space(ClA.search_space_type(algo), algo, model, input)
    output = ClA.tree_search(algo.explore, diving_space, env, input)
    LOG_ATI1 && println("~~~~~~~~ end of Diving ~~~~~~~~")
    return output
end

# At last, we define the algorithm that will conquer each node of the binary tree algorithm.
# It runs the `ComputeSolCostAti1` algorithm and then the diving algorithm if the two first
# variables have been fixed (i.e. if depth == 2).
@with_kw struct BtConquerAti1 <: ClA.AbstractAlgorithm
    compute = ComputeSolCostAti1(log = "compute solution cost for Binary tree")
    heuristic = DivingAti1()
end

function ClA.run!(algo::BtConquerAti1, env, model, input)
    output = run!(algo.compute, env, model, input)
    diving_output = Inf
    if input.current_node.depth == 2
        diving_input = DivingInputAti1(input.current_node) # TODO: needs an interface or specific to the algorithm ?
        diving_output = run!(algo.heuristic, env, model, diving_input)
    end
    return min(output, diving_output) 
end

# ## Interface implementation

@with_kw struct TreeSearchAlgorithmAti1
    conqueralg = ClA.ColCutGenConquer()
    dividealg = ClA.SimpleBranching()
    explorestrategy = ClA.DepthFirstStrategy()
end

function ClA.run!(algo::TreeSearchAlgorithmAti1, env, reform, input)
    search_space = ClA.new_space(ClA.search_space_type(algo), algo, reform, input)
    return ClA.tree_search(algo.explorestrategy, search_space, env, input)
end

# We start by implementing methods that create the search space and the root node for each
# tree search algorithm that will be run.

# First, we must indicate the type of search space used by our algorithms.
# We need such a method because the type may depends from the algorithms called by the
# tree-search algorithm.
ClA.search_space_type(::TreeSearchAlgorithmAti1) = BtSearchSpaceAti1
ClA.search_space_type(::DivingAti1) = DivingSearchSpaceAti1 

# The type of the search space is known from above method.
# A search space may receive information from the tree-search algorithm. 
# The `model`, and `input` arguments are those received by the tree search algorithm.
ClA.new_space(::Type{BtSearchSpaceAti1}, alg, model, input) =
    BtSearchSpaceAti1(model, alg.conqueralg, alg.dividealg)
ClA.new_space(::Type{DivingSearchSpaceAti1}, alg, model, input) =
    DivingSearchSpaceAti1(model, input.starting_node_in_parent_algorithm, alg.conqueralg, alg.dividealg)

# The definition of the root node depends on the search space.
ClA.new_root(::BtSearchSpaceAti1, input) = NodeAti1()
ClA.new_root(space::DivingSearchSpaceAti1, input) = 
    NodeAti1(space.starting_node_in_bt)

# Then, we implement the method that converts the branching rules into nodes for the tree 
# search algorithm.
function ClA.new_children(::ClA.AbstractColunaSearchSpace, branches, node::NodeAti1)
    children = NodeAti1[]
    for (var_pos, var_val_fixed) in branches
        child = NodeAti1(node, var_pos, var_val_fixed)
        push!(children, child)
    end
    return children
end

struct CustomBestFirstSearchAti1 <: ClA.AbstractBestFirstSearch end

# We implement the priority method for the `CustomBestFirstSearchAti1` strategy.
# The tree search algorithm will evaluate the node with highest priority.
ClA.get_priority(::CustomBestFirstSearchAti1, node::NodeAti1) = -node.depth

# We implement the `node_change` method to update the search space when the tree search
# just after the algorithm finishes to evaluate a node and chooses the next one.

# There are two ways to store the state of a formulation at a given node.
# We can distribute information across the nodes or store the whole state at each node.
# We follow the second way (so we don't need `previous`).
function ClA.node_change!(::NodeAti1, next::NodeAti1, space::ClA.AbstractColunaSearchSpace, _)
    for (var_pos, bounds) in enumerate(Iterators.zip(next.var_lbs, next.var_ubs))
       space.formulation.var_domains[var_pos] = bounds 
    end
    return
end

# We implement methods that update the best solution found after the conquer algorithm.
# One method for each search space.
function ClA.after_conquer!(space::BtSearchSpaceAti1, current, output)
    if output < space.cost_of_best_solution
        space.cost_of_best_solution = output
    end
    return
end

function ClA.after_conquer!(space::DivingSearchSpaceAti1, current, output)
    if output < space.cost_of_best_solution
        space.cost_of_best_solution = output
    end
    return
end

# We implement getters to retrieve the input from the search space and the node. 
# The input is passed to the conquer and the divide algorithms.
ClA.get_input(::BtConquerAti1, space::BtSearchSpaceAti1, node::NodeAti1) = 
    ComputeSolCostInputAti1(node)
ClA.get_input(::DivideAti1, space::BtSearchSpaceAti1, node::NodeAti1) = 
    DivideInputAti1(node)
ClA.get_input(::ComputeSolCostAti1, space::DivingSearchSpaceAti1, node::NodeAti1) =
    ComputeSolCostInputAti1(node)
ClA.get_input(::DivideAti1, space::DivingSearchSpaceAti1, node::NodeAti1) =
    DivideInputAti1(node)

# At last, we implement methods that will return the output of the tree search algorithms.
# One method for each search space.
ClA.tree_search_output(space::BtSearchSpaceAti1, _) = space.cost_of_best_solution
ClA.tree_search_output(space::DivingSearchSpaceAti1, _) = space.cost_of_best_solution

@testset "Algorithm - treesearch interface" begin
    env = nothing
    model = FormulationAti1()
    input = nothing

    treesearch = TreeSearchAlgorithmAti1(
        conqueralg = BtConquerAti1(),
        dividealg = DivideAti1(),
        explorestrategy = ClA.DepthFirstStrategy()
    )

    output = ClA.run!(treesearch, env, model, input)
    @test output == -1

    treesearch = TreeSearchAlgorithmAti1(
        conqueralg = BtConquerAti1(),
        dividealg = DivideAti1(),
        explorestrategy = CustomBestFirstSearchAti1()
    )
    output = ClA.run!(treesearch, env, model, input)
    @test output == -1
end

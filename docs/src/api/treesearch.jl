# # Tree search API
# ## Introduction

# This is a test (and also a tutorial) on how to use the tree search interface together with
# algorithms.

# We define the dependencies:

using Coluna, Parameters;

# and some shortcuts for the sake of brevity:
const ClA = Coluna.Algorithm;
const ClB = Coluna.ColunaBase;


# We consider a minimization problem with four binary variables.
# Costs of the variable are `[-1, 1, 1, 1]`.
# The problem has no additional constraints. 
# Therefore, the optimal solution is `[1, 0, 0, 0]`.

# Let's define a data structure that will maintain the formulation of the problem.
# Vector `var_costs` contains the costs of the variables.
# Vector `var_domains` contains the lower and upper bounds (in a tuple) of the variables.

const NB_VARIABLES_ = 4

struct Formulation <: ClB.AbstractModel
    var_costs::Vector{Int}
    var_domains::Vector{Tuple{Int,Int}}
    Formulation() = new([-1, 1, 1, 1], fill((0,1), NB_VARIABLES_))
end

# We are going to enumerate all possible values for the two first variables using
# a binary tree: 
#  - depth 0: branch on the first variable
#  - depth 1: branch on the second variable
#
# When the two first variables are fixed, we dive to fix the third and the fourth
# variables to zero.
#
#
# At the end, the tree will look like:
#
# 
# ```@raw html
# <div class="mermaid">
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
# </div>
# ```
#
# The nodes in blue are explored by a binary tree algorithm.
# The nodes in red are explored by a diving algorithm. 

# ## Implementing tree search data structures

# Now, we define the two concepts we'll use in the tree search algorithms: 
# the *node* and the *search space*.
# The third concept is the *explore strategy* and implemented in Coluna.

# We start by defining the node. Take a look at the API section to see
# the list of methods you need to implement.

struct Node <: Coluna.TreeSearch.AbstractNode
    depth::Int
    solution::Vector{Float64}
    var_lbs::Vector{Int}
    var_ubs::Vector{Int}
    parent::Union{Nothing, Node}

    ## The constructor just build the solution.
    function Node(
        parent::Union{Nothing, Node} = nothing,
        var_index::Union{Nothing,Int} = nothing,
        var_value::Union{Nothing,Real} = 0
    )
        @assert isnothing(var_index) || 1 <= var_index <= NB_VARIABLES_
        depth = isnothing(parent) ? 0 : parent.depth + 1
        ## Store the solution at this node.
        solution = if isnothing(parent)
            fill(0.5, NB_VARIABLES_)
        else
            sol = copy(parent.solution)
            if !isnothing(var_index)
                sol[var_index] = var_value
            end
            sol
        end
        ## Store the state of the formulation.
        var_lbs = map(var_val -> var_val == 0.5 ? 0 : var_val, solution)
        var_ubs = map(var_val -> var_val == 0.5 ? 1 : var_val, solution)
        return new(
            depth,
            solution,
            var_lbs,
            var_ubs,
            parent
        )
    end
end

Coluna.TreeSearch.get_root(node::Node) = isnothing(node.parent) ? node : ClA.root(node.parent)
Coluna.TreeSearch.get_parent(node::Node) = node.parent


# Then, we define the search spaces. Take a look at the API section to see
# the list of methods you need to implement.


const LOG_ = true;

# Every tree search algorithm must be associated with a search space.

# So here, we'll implement two search spaces.
# One for the binary tree and another for the diving.

# Let's start with the search space of the binary tree algorithm.

mutable struct BtSearchSpace <: ClA.AbstractColunaSearchSpace
    formulation::Formulation
    cost_of_best_solution::Float64
    conquer_alg
    divide_alg
    previous::Union{Node,Nothing}
    BtSearchSpace(form, conquer, divide) = new(form, Inf, conquer, divide, nothing)
end

ClA.get_reformulation(sp::BtSearchSpace) = sp.formulation
ClA.get_conquer(sp::BtSearchSpace) = sp.conquer_alg
ClA.get_divide(sp::BtSearchSpace) = sp.divide_alg
ClA.get_previous(sp::BtSearchSpace) = sp.previous
ClA.set_previous!(sp::BtSearchSpace, previous) = sp.previous = previous
Coluna.TreeSearch.stop(sp::BtSearchSpace, _) = false

# Then, we implement the search space of the diving.

mutable struct DivingSearchSpace <: ClA.AbstractColunaSearchSpace
    formulation::Formulation
    starting_node_in_bt::Coluna.TreeSearch.AbstractNode # change node
    cost_of_best_solution::Float64
    conquer_alg
    divide_alg
    previous
    DivingSearchSpace(form, node, conquer, divide) = new(form, node, Inf, conquer, divide, nothing)
end

ClA.get_reformulation(sp::DivingSearchSpace) = sp.formulation
ClA.get_conquer(sp::DivingSearchSpace) = sp.conquer_alg
ClA.get_divide(sp::DivingSearchSpace) = sp.divide_alg
ClA.get_previous(sp::DivingSearchSpace) = sp.previous
ClA.set_previous!(sp::DivingSearchSpace, previous) = sp.previous = previous
Coluna.TreeSearch.stop(sp::DivingSearchSpace, _) = false

# ## Writing algorithms

# Let's define the algorithm that we will use.

# At each node, we define an algorithm `ComputeSolCost` that computes the cost of the
# solution and returns its value.

@with_kw struct ComputeSolCost <: Coluna.AlgoAPI.AbstractAlgorithm 
    log::String = "compute solution cost"
end

struct ComputeSolCostInput
    current_node::Node
end

function ClA.run!(algo::ComputeSolCost, env, model::Formulation, input::ComputeSolCostInput)
    LOG_ && println("== $(algo.log) ==")
    LOG_ && @show model.var_domains
    sol_cost = 0.0
    for (cost, (ub, lb)) in Iterators.zip(model.var_costs, model.var_domains)
        var_val = ub == lb ? ub : 0.5
        sol_cost += var_val * cost
    end
    return sol_cost
end

# To generate, the children, we create an algorithm named `Divide` that will create,
# for a given variable x, both branches x <= 0 & x >= 1 or only branch x = 0 depending on
# parameters are chosen.

@with_kw struct Divide <: Coluna.AlgoAPI.AbstractAlgorithm
    log::String = "classic divide"
    create_both_branches::Bool = true
end

struct DivideInput
    current_node::Node
end

function ClA.run!(algo::Divide, env, ::Formulation, input::DivideInput)
    LOG_ && println(algo.log)
    parent = input.current_node
    if algo.create_both_branches && parent.depth < 2
        var_pos_to_branch_in = parent.depth + 1
        var_pos_to_branch_in > 4 && return []
        LOG_ && println("** branch on x$(var_pos_to_branch_in) == 0 & x$(var_pos_to_branch_in) == 1")
        return [(var_pos_to_branch_in, 0), (var_pos_to_branch_in, 1)]
    elseif !algo.create_both_branches
        var_pos_to_branch_in = parent.depth
        var_pos_to_branch_in > 4 && return []
        LOG_ && println("** branch on x$(var_pos_to_branch_in) == 0")
        return [(var_pos_to_branch_in, 0)]
    end
    return []
end

# The diving is a tree search algorithm that uses:
#  - `ComputeSolCost` as conquer strategy
#  - `Divide` with parameter `create_both_branches` equal to `false` as the divide strategy
#  - `Coluna.Algorithm.DepthFirstStrategy` as explore strategy

@with_kw struct Diving <: Coluna.AlgoAPI.AbstractAlgorithm
    conqueralg = ComputeSolCost(log="compute solution cost of Diving tree")
    dividealg = Divide(
        log = "divide for diving",
        create_both_branches = false
    )
    explore = Coluna.TreeSearch.DepthFirstStrategy()
end

struct DivingInput
    starting_node_in_parent_algorithm
end

function ClA.run!(algo::Diving, env, model::Formulation, input::DivingInput)
    LOG_ && println("~~~~~~~~ Diving starts ~~~~~~~~")
    diving_space = Coluna.TreeSearch.new_space(Coluna.TreeSearch.search_space_type(algo), algo, model, input)
    output = Coluna.TreeSearch.tree_search(algo.explore, diving_space, env, input)
    LOG_ && println("~~~~~~~~ end of Diving ~~~~~~~~")
    return output
end

# We define the algorithm that will conquer each node of the binary tree algorithm.
# It runs the `ComputeSolCost` algorithm and then the diving algorithm if the two first
# variables have been fixed (i.e. if depth == 2).
@with_kw struct BtConquer <: Coluna.AlgoAPI.AbstractAlgorithm
    compute = ComputeSolCost(log = "compute solution cost for Binary tree")
    heuristic = Diving()
end

function ClA.run!(algo::BtConquer, env, model, input)
    output = ClA.run!(algo.compute, env, model, input)
    diving_output = Inf
    if input.current_node.depth == 2
        diving_input = DivingInput(input.current_node) # TODO: needs an interface or specific to the algorithm?
        diving_output = ClA.run!(algo.heuristic, env, model, diving_input)
    end
    return min(output, diving_output) 
end

# The binary tree algorithm is a tree search algorithm that uses:
#  - `BtConquer` as conquer strategy
#  - `Divide` with parameter `create_both_branches` equal to `false` as the divide strategy
#  - `Coluna.Algorithm.DepthFirstStrategy` as explore strategy

@with_kw struct BinaryTree <: Coluna.AlgoAPI.AbstractAlgorithm
    conqueralg = BtConquer()
    dividealg = Divide()
    explore = Coluna.TreeSearch.DepthFirstStrategy()
end

# Look at how we call the generic tree search implementation.

function ClA.run!(algo::BinaryTree, env, reform, input)
    search_space = Coluna.TreeSearch.new_space(Coluna.TreeSearch.search_space_type(algo), algo, reform, input)
    return Coluna.TreeSearch.tree_search(algo.explore, search_space, env, input)
end

# ## Implementing tree search interface

# First, we indicate the type of search space used by our algorithms.
# Note that the type of the search space can depend on the configuration of the algorithm.
# So there is a 1-to-n relation between tree search algorithm configurations and search space.
# because one search space can be used by several tree search algorithms configuration.

Coluna.TreeSearch.search_space_type(::BinaryTree) = BtSearchSpace
Coluna.TreeSearch.search_space_type(::Diving) = DivingSearchSpace 

# Now, we implement the method that calls the constructor of a search space.
# The type of the search space is known from the above method.
# A search space may receive information from the tree-search algorithm. 
# The `model`, and `input` arguments are the same as those received by the tree search algorithm.

Coluna.TreeSearch.new_space(::Type{BtSearchSpace}, alg, model, input) =
    BtSearchSpace(model, alg.conqueralg, alg.dividealg)
Coluna.TreeSearch.new_space(::Type{DivingSearchSpace}, alg, model, input) =
    DivingSearchSpace(model, input.starting_node_in_parent_algorithm, alg.conqueralg, alg.dividealg)

# We implement the method that returns the root node.
# The definition of the root node depends on the search space.

Coluna.TreeSearch.new_root(::BtSearchSpace, input) = Node()
Coluna.TreeSearch.new_root(space::DivingSearchSpace, input) = 
    Node(space.starting_node_in_bt)

# Then, we implement the method that converts the branching rules into nodes for the tree 
# search algorithm.

function ClA.new_children(::ClA.AbstractColunaSearchSpace, branches, node::Node)
    children = Node[]
    for (var_pos, var_val_fixed) in branches
        child = Node(node, var_pos, var_val_fixed)
        push!(children, child)
    end
    return children
end

# We implement the `node_change` method to update the search space called by the tree search
# algorithm just after it finishes evaluating a node and chooses the next one.
# Be careful, this method is not called after the evaluation of a node when there are no
# more unevaluated nodes (i.e. tree exploration is finished).

# There are two ways to store the state of a formulation at a given node.
# We can distribute information across the nodes or store the whole state at each node.
# We follow the second way (so we don't need `previous`).

function ClA.node_change!(::Node, next::Node, space::ClA.AbstractColunaSearchSpace, _)
    for (var_pos, bounds) in enumerate(Iterators.zip(next.var_lbs, next.var_ubs))
       space.formulation.var_domains[var_pos] = bounds 
    end
    return
end

# Method `after_conquer` is a callback to do some operations after the conquer of a node
# and before the divide.
# Here, we update the best solution found after the conquer algorithm.
# We implement one method for each search space.

function ClA.after_conquer!(space::BtSearchSpace, current, output)
    if output < space.cost_of_best_solution
        space.cost_of_best_solution = output
    end
    return
end

function ClA.after_conquer!(space::DivingSearchSpace, current, output)
    if output < space.cost_of_best_solution
        space.cost_of_best_solution = output
    end
    return
end

# We implement getters to retrieve the input from the search space and the node. 
# The input is passed to the conquer and the divide algorithms.

ClA.get_input(::BtConquer, space::BtSearchSpace, node::Node) = 
    ComputeSolCostInput(node)
ClA.get_input(::Divide, space::BtSearchSpace, node::Node) = 
    DivideInput(node)
ClA.get_input(::ComputeSolCost, space::DivingSearchSpace, node::Node) =
    ComputeSolCostInput(node)
ClA.get_input(::Divide, space::DivingSearchSpace, node::Node) =
    DivideInput(node)

# At last, we implement methods that will return the output of the tree search algorithms.
# We return the cost of the best solution found.
# We write one method for each search space.

Coluna.TreeSearch.tree_search_output(space::BtSearchSpace, _) = space.cost_of_best_solution
Coluna.TreeSearch.tree_search_output(space::DivingSearchSpace, _) = space.cost_of_best_solution

# ## Run the example

# We run our tree search algorithm:

env = nothing
model = Formulation()
input = nothing

output = ClA.run!(BinaryTree(), env, model, input)
@show output

# ## API

# ### Search space

# ```@docs
# Coluna.TreeSearch.AbstractSearchSpace
# Coluna.TreeSearch.search_space_type
# Coluna.TreeSearch.new_space
# ```

# ### Node 

# ```@docs
# Coluna.TreeSearch.AbstractNode
# Coluna.TreeSearch.new_root
# Coluna.TreeSearch.get_root
# Coluna.TreeSearch.get_parent
# Coluna.TreeSearch.get_priority
# ```
# Additional methods needed for Coluna's algorithms:
# ```@docs
# Coluna.TreeSearch.get_opt_state
# Coluna.TreeSearch.get_records
# Coluna.TreeSearch.get_branch_description
# Coluna.TreeSearch.isroot
# ```

# ### Tree search algorithm

# ```@docs
# Coluna.TreeSearch.AbstractExploreStrategy
# Coluna.TreeSearch.tree_search
# Coluna.TreeSearch.children
# Coluna.TreeSearch.stop
# Coluna.TreeSearch.tree_search_output
# ```

# ### Tree search algorithm for Coluna

# ```@docs
# Coluna.Algorithm.AbstractColunaSearchSpace
# ```

# The `children` method has a specific implementation for `AbstractColunaSearchSpace``
# that involves following methods:

# ```@docs
# Coluna.Algorithm.get_previous
# Coluna.Algorithm.set_previous!
# Coluna.Algorithm.node_change!
# Coluna.Algorithm.get_divide
# Coluna.Algorithm.get_reformulation
# Coluna.Algorithm.get_input
# Coluna.Algorithm.after_conquer!
# Coluna.Algorithm.new_children
# ```


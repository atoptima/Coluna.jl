"""
    Coluna.Algorithm.TreeSearchAlgorithm(
        presolvealg = nothing,
        conqueralg::AbstractConquerAlgorithm = ColCutGenConquer(),
        dividealg::AbstractDivideAlgorithm = Branching(),
        explorestrategy::AbstractExploreStrategy = DepthFirstStrategy(),
        maxnumnodes = 100000,
        opennodeslimit = 100,
        timelimit = -1, # -1 means no time limit
        opt_atol::Float64 = DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = DEF_OPTIMALITY_RTOL,
        branchingtreefile = "",
        jsonfile = "",
        print_node_info = true
    )

This algorithm is a branch and bound that uses a search tree to optimize the reformulation.
At each node in the tree, it applies `conqueralg` to evaluate the node and improve the bounds, 
`dividealg` to generate branching constraints, and `explorestrategy`
to select the next node to treat. Optionally, the `presolvealg` is run in the beginning to 
preprocess the formulation.

The three main elements of the algorithm are:
- the conquer strategy (`conqueralg`): evaluation of the problem at a node of the Branch-and-Bound tree. Depending on the type of decomposition used ahead of the Branch-and-Bound, you can use either Column Generation (if your problem is decomposed following Dantzig-Wolfe transformation) and/or Cut Generation (for Dantzig-Wolfe and Benders decompositions). 
- the branching strategy (`dividealg`): how to create new branches i.e. how to divide the search space
- the explore strategy (`explorestrategy`): the evaluation order of your nodes 

Parameters: 
- `maxnumnodes` : maximum number of nodes explored by the algorithm
- `opennodeslimit` : maximum number of nodes waiting to be explored
- `timelimit` : time limit in seconds of the algorithm
- `opt_atol` : optimality absolute tolerance (alpha)
- `opt_rtol` : optimality relative tolerance (alpha)

Options:
- `branchingtreefile` : name of the file in which the algorithm writes an overview of the branching tree
- `jsonfile` : name of the file in which the algorithm writes the solution in JSON format
- `print_node_info` : log the tree into the console

**Warning**: if you set a name for the `branchingtreefile` AND the `jsonfile`, the algorithm will only write
in the json file.
"""
struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    presolvealg::Union{Nothing,PresolveAlgorithm}
    conqueralg::AbstractConquerAlgorithm
    dividealg::AlgoAPI.AbstractDivideAlgorithm
    explorestrategy::TreeSearch.AbstractExploreStrategy
    maxnumnodes::Int64
    opennodeslimit::Int64
    timelimit::Int64
    opt_atol::Float64
    opt_rtol::Float64
    branchingtreefile::String
    jsonfile::String
    print_node_info::Bool
    TreeSearchAlgorithm(;
        presolvealg = nothing,
        conqueralg = ColCutGenConquer(),
        dividealg = ClassicBranching(),
        explorestrategy = TreeSearch.DepthFirstStrategy(),
        maxnumnodes = 100000,
        opennodeslimit = 100,
        timelimit = -1, # means no time limit
        opt_atol = AlgoAPI.default_opt_atol(),
        opt_rtol = AlgoAPI.default_opt_rtol(),
        branchingtreefile = "",
        jsonfile = "",
        print_node_info = true
    ) = new(presolvealg, conqueralg, dividealg, explorestrategy, maxnumnodes, opennodeslimit, timelimit, opt_atol, opt_rtol, branchingtreefile, jsonfile, print_node_info)
end

# TreeSearchAlgorithm is a manager algorithm (manages storing and restoring storage units)
ismanager(algo::TreeSearchAlgorithm) = true

# TreeSearchAlgorithm does not use any record itself, 
# therefore get_units_usage() is not defined for it
function get_child_algorithms(algo::TreeSearchAlgorithm, reform::Reformulation) 
    child_algos = Dict(
        "conquer" => (algo.conqueralg, reform),
        "divide" => (algo.dividealg, reform)
    )
    if !isnothing(algo.presolvealg)
        child_algos["presolve"] = (algo.presolvealg, reform)
    end
    return child_algos
end

function run!(algo::TreeSearchAlgorithm, env::Env, reform::Reformulation, input::OptimizationState)
    # TreeSearchAlgorithm is the only algorithm that changes the global time limit in the
    # environment. However, time limit set from JuMP/MOI has priority.
    if env.global_time_limit == -1
        env.global_time_limit = algo.timelimit
    else
        @warn "Global time limit has been set through JuMP/MOI. Ignoring the time limit of TreeSearchAlgorithm."
    end

    if !isnothing(algo.presolvealg)
        if !isfeasible(run!(algo.presolvealg, env, reform, PresolveInput()))
            output = input
            setterminationstatus!(output, ColunaBase.INFEASIBLE)
            return output
        end
    end

    search_space = TreeSearch.new_space(TreeSearch.search_space_type(algo), algo, reform, input)
    return TreeSearch.tree_search(algo.explorestrategy, search_space, env, input)
end

############################################################################################
# Tree search interface for Coluna algorithms
############################################################################################
"Search space for tree search algorithms in Coluna."
abstract type AbstractColunaSearchSpace <: TreeSearch.AbstractSearchSpace end

# Additional methods to implement to use the tree search algorithms together with Coluna's
# algorithms.
"Returns the previous node explored by the tree search algorithm."
@mustimplement "ColunaSearchSpace" get_previous(s::AbstractColunaSearchSpace) = nothing

"Sets the previous node explored by the tree search algorithm."
@mustimplement "ColunaSearchSpace" set_previous!(s::AbstractColunaSearchSpace, previous) = nothing

"Returns the conquer algorithm."
@mustimplement "ColunaSearchSpace" get_conquer(sp::AbstractColunaSearchSpace) = nothing

"Returns the divide algorithm."
@mustimplement "ColunaSearchSpace" get_divide(sp::AbstractColunaSearchSpace) = nothing

"Returns the reformulation that will be passed to an algorithm."
@mustimplement "ColunaSearchSpace" get_reformulation(s::AbstractColunaSearchSpace) = nothing

"""
Returns the input that will be passed to an algorithm.
The input can be built from information contained in a search space and a node.
"""
@mustimplement "ColunaSearchSpace" get_input(a::AlgoAPI.AbstractAlgorithm, s::AbstractColunaSearchSpace, n::TreeSearch.AbstractNode) = nothing

"""
Methods to perform operations before the tree search algorithm evaluates a node (`current`).
This is useful to restore the state of the formulation for instance.
"""
@mustimplement "ColunaSearchSpace" node_change!(previous::TreeSearch.AbstractNode, current::TreeSearch.AbstractNode, space::AbstractColunaSearchSpace) = nothing

"""
Methods to perform operations after the conquer algorithms.
It receives the output of the conquer algorithm.
"""
@mustimplement "ColunaSearchSpace" after_conquer!(::AbstractColunaSearchSpace, current, output) = nothing

"Returns the number of children generated by the divide algorithm."
@mustimplement "ColunaSearchSpace" number_of_children(divide_output) = nothing

"""
Performs operations after the divide algorithm when the current node is finally a leaf.
"""
@mustimplement "ColunaSearchSpace" node_is_leaf(::AbstractColunaSearchSpace, current, output) = nothing

"Creates and returns the children of a node associated to a search space."
@mustimplement "ColunaSearchSpace" new_children(sp::AbstractColunaSearchSpace, candidates, n::TreeSearch.AbstractNode) = nothing

@mustimplement "ColunaSearchSpace" run_divide(sp::AbstractColunaSearchSpace, divide_input) = nothing


"Returns true if the current node should not be explored i.e. if its local dual bound inherited from its parent is worst than a primal bound of the search space."
@mustimplement "ColunaSearchSpace" is_pruned(sp::AbstractColunaSearchSpace, current) = nothing

"Method to perform some operations if the current node is pruned."
@mustimplement "ColunaSearchSpace" node_is_pruned(sp::AbstractColunaSearchSpace, current) = nothing

# Implementation of the `children` method for the `AbstractColunaSearchSpace` algorithm.
function TreeSearch.children(space::AbstractColunaSearchSpace, current::TreeSearch.AbstractNode, env)
    # restore state of the formulation for the current node.
    previous = get_previous(space)
    if !isnothing(previous)
        node_change!(previous, current, space)
    end
    set_previous!(space, current)
    # We should avoid the whole exploration of a node if its local dual bound inherited from its parent is worst than a primal bound found elsewhere on the tree. 
    if is_pruned(space, current)
        node_is_pruned(space, current)
        return []
    end
    # Else we run the conquer algorithm.
    # This algorithm has the responsibility to check whether the node is pruned.
    reform = get_reformulation(space)
    conquer_output = TreeSearch.get_conquer_output(current)
    if conquer_output === nothing
        conquer_alg = get_conquer(space)
        conquer_input = get_input(conquer_alg, space, current)
        conquer_output = run!(conquer_alg, env, reform, conquer_input)         
        after_conquer!(space, current, conquer_output) # callback to do some operations after the conquer.
    end
    # Build the divide input from the conquer output
    divide_alg = get_divide(space)
    divide_input = get_input(divide_alg, space, current, conquer_output)
    branches = nothing
    # if `run_divide` returns false, the divide is not run and the node is pruned. 
    if run_divide(space, divide_input)
        branches = run!(divide_alg, env, reform, divide_input)
    end
    if isnothing(branches) || number_of_children(branches) == 0
        node_is_leaf(space, current, conquer_output) # callback to do some operations when the node is a leaf.
        return [] # node is pruned, no children is generated
    end
    return new_children(space, branches, current)
end

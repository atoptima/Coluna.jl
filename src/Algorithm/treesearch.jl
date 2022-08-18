"""
    Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg::AbstractConquerAlgorithm = ColCutGenConquer(),
        dividealg::AbstractDivideAlgorithm = SimpleBranching(),
        explorestrategy::AbstractExploreStrategy = DepthFirstStrategy(),
        maxnumnodes::Int = 100000,
        opennodeslimit::Int = 100,
        opt_atol::Float64 = DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = DEF_OPTIMALITY_RTOL,
        branchingtreefile = ""
    )

This algorithm is a branch and bound that uses a search tree to optimize the reformulation.
At each node in the tree, it applies `conqueralg` to improve the bounds, 
`dividealg` to generate child nodes, and `explorestrategy`
to select the next node to treat.

Parameters : 
- `maxnumnodes` : maximum number of nodes explored by the algorithm
- `opennodeslimit` : maximum number of nodes waiting to be explored
- `opt_atol` : optimality absolute tolerance (alpha)
- `opt_rtol` : optimality relative tolerance (alpha)

Options :
- `branchingtreefile` : name of the file in which the algorithm writes an overview of the branching tree
"""
@with_kw struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColCutGenConquer()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000
    opennodeslimit::Int64 = 100 
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL
    branchingtreefile::String = ""
    skiprootnodeconquer = false # true for diving heuristics
    storelpsolution = false
    print_node_info = true
end

# TreeSearchAlgorithm is a manager algorithm (manages storing and restoring storage units)
ismanager(algo::TreeSearchAlgorithm) = true

# TreeSearchAlgorithm does not use any record itself, 
# therefore get_units_usage() is not defined for it
function get_child_algorithms(algo::TreeSearchAlgorithm, reform::Reformulation) 
    return [(algo.conqueralg, reform), (algo.dividealg, reform)]
end

function run!(algo::TreeSearchAlgorithm, env::Env, reform::Reformulation, input::OptimizationInput)
    search_space = new_space(search_space_type(algo), algo, reform, input)
    return tree_search(algo.explorestrategy, search_space, env, input)
end

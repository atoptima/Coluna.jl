"""
    Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg::AbstractConquerAlgorithm = ColCutGenConquer(),
        dividealg::AbstractDivideAlgorithm = Branching(),
        explorestrategy::AbstractExploreStrategy = DepthFirstStrategy(),
        maxnumnodes = 100000,
        opennodeslimit = 100,
        timelimit = -1, # -1 means no time limit
        opt_atol::Float64 = DEF_OPTIMALITY_ATOL,
        opt_rtol::Float64 = DEF_OPTIMALITY_RTOL,
        branchingtreefile = ""
    )

This algorithm is a branch and bound that uses a search tree to optimize the reformulation.
At each node in the tree, it applies `conqueralg` to evaluate the node and improve the bounds, 
`dividealg` to generate branching constraints, and `explorestrategy`
to select the next node to treat.

Parameters : 
- `maxnumnodes` : maximum number of nodes explored by the algorithm
- `opennodeslimit` : maximum number of nodes waiting to be explored
- `timelimit` : time limit in seconds of the algorithm
- `opt_atol` : optimality absolute tolerance (alpha)
- `opt_rtol` : optimality relative tolerance (alpha)

Options :
- `branchingtreefile` : name of the file in which the algorithm writes an overview of the branching tree
"""
@with_kw struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColCutGenConquer()
    dividealg::AbstractDivideAlgorithm = Branching()
    explorestrategy::AbstractExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000
    opennodeslimit::Int64 = 100
    timelimit::Int64 = -1 # means no time limit
    opt_atol::Float64 = Coluna.DEF_OPTIMALITY_ATOL
    opt_rtol::Float64 = Coluna.DEF_OPTIMALITY_RTOL
    branchingtreefile::String = ""
    print_node_info = true
end

# TreeSearchAlgorithm is a manager algorithm (manages storing and restoring storage units)
ismanager(algo::TreeSearchAlgorithm) = true

# TreeSearchAlgorithm does not use any record itself, 
# therefore get_units_usage() is not defined for it
function get_child_algorithms(algo::TreeSearchAlgorithm, reform::Reformulation) 
    return [(algo.conqueralg, reform), (algo.dividealg, reform)]
end

function run!(algo::TreeSearchAlgorithm, env::Env, reform::Reformulation, input::OptimizationState)
    # TreeSearchAlgorithm is the only algorithm that changes the global time limit in the
    # environment. However, time limit set from JuMP/MOI has priority.
    if env.global_time_limit == -1
        env.global_time_limit = algo.timelimit
    else
        @warn "Global time limit has been set through JuMP/MOI. Ignoring the time limit of TreeSearchAlgorithm."
    end
    search_space = new_space(search_space_type(algo), algo, reform, input)
    return tree_search(algo.explorestrategy, search_space, env, input)
end

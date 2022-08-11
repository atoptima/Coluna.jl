@with_kw struct NewTreeSearchAlgorithm
    conqueralg = ColCutGenConquer()
    dividealg = SimpleBranching()
    explorestrategy = DepthFirstStrategy()
end

# Each conquer algorithm must have a search space.
function run!(algo::NewTreeSearchAlgorithm, env, reform, input)
    search_space = new_space(search_space_type(algo), algo, reform, input)
    return tree_search(algo.explorestrategy, search_space, env, input)
end
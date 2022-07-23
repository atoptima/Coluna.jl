@with_kw struct NewTreeSearchAlgorithm
    conqueralg = ColCutGenConquer()
    dividealg = SimpleBranching()
    explorestrategy = DepthFirstExploreStrategy()
end

# Each conquer algorithm must have a search space.
function run!(algo::NewTreeSearchAlgorithm, env, reform, input)
    conquer_space = new_space(algo.conqueralg, env, reform, input)
    tree_search(algo.explorestrategy, algo.conqueralg, algo.dividealg, conquer_space, env)
end
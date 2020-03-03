include("masteripheur.jl")

struct UnknownAlgo <: ClA.AbstractOptimizationAlgorithm end

function algorithm_unit_tests()
    masteripheur_tests()
end


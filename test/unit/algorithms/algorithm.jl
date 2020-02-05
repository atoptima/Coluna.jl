include("masteripheur.jl")

struct UnknownAlgo <: ClA.AbstractOptimizationAlgorithm end

function algorithm_unit_tests()
    #algorithm_fallbacks_tests()
    masteripheur_tests()
end

function algorithm_fallbacks_tests()
    # @test_throws ErrorException CL.prepare!(ClA.UnknownAlgo(), nothing, nothing)
    # @test_throws ErrorException CL.run!(ClA.UnknownAlgo(), ClF.Reformulation(), ClA.OptimizationInput())
end

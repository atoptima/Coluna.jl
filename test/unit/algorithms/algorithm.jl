include("masteripheur.jl")

struct UnknownAlgo <: CL.AbstractAlgorithm end

function algorithm_unit_tests()
    #algorithm_fallbacks_tests()
    masteripheur_tests()
end

function algorithm_fallbacks_tests()
    @test_throws ErrorException CL.prepare!(CL.UnknownAlgo(), nothing, nothing)
    @test_throws ErrorException CL.run!(CL.UnknownAlgo(), nothing, nothing)
end

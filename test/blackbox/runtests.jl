
include("originalformulation.jl")

@testset "Blackbox tests" begin

    @testset "Original Formulation SGAP" begin
        blackbox_original_formulation_sgap()
    end
    
end
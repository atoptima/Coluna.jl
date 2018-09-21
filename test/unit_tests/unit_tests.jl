include("varconstr.jl")
include("variables.jl")

function unit_tests()
    @testset "varconstr.jl" begin
        varconstr_unit_tests()
    end
    @testset "variables.jl" begin
        variables_unit_tests()
    end

end


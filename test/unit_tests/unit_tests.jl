include("utils.jl")
include("varconstr.jl")
include("variables.jl")
include("constraints.jl")
include("solution.jl")

function unit_tests()
    @testset "varconstr.jl" begin
        varconstr_unit_tests()
    end
    @testset "variables.jl" begin
        variables_unit_tests()
    end
    @testset "constraints.jl" begin
        constraints_unit_tests()
    end
    @testset "solution.jl" begin
        solution_unit_tests()
    end

end


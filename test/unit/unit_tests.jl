include("containers/nestedenum.jl")
include("containers/solsandbounds.jl")

include("MathProg/types.jl")
include("MathProg/variables.jl")

include("algorithms/algorithm.jl")

include("counters.jl")
include("variable.jl")
include("constraint.jl")

function unit_tests()
    @testset "ColunaBase submodule" begin
        nestedenum_unit()
        bound_unit()
        solution_unit()
    end

    @testset "MathProg submodule" begin
        @testset "types.jl" begin
            types_unit_tests()
            variables_unit_tests()
        end
    end

    @testset "algorithm.jl" begin
        algorithm_unit_tests()
    end

    @testset "counters.jl" begin
        counters_unit_tests()
    end

    @testset "variable.jl" begin
        variable_unit_tests()
    end
    @testset "constraint.jl" begin
        constraint_unit_tests()
    end

    return
end

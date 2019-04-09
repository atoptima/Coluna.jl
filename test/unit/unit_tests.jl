include("constraint.jl")
include("variable.jl")
include("vcids.jl")
include("vcdict.jl")

function unit_tests()
    # @testset "Filename" begin
    #    filename_unit_tests()
    # end

    @testset "constraint.jl" begin
        constraint_unit_tests()
    end

    @testset "variable.jl" begin
        variable_unit_tests()
    end

    @testset "vcids.jl" begin
        vcids_unit_tests()
    end

    @testset "vcdict.jl" begin
        vcdict_unit_tests()
    end
    return
end
include("containers/nestedenum.jl")
include("containers/solsandbounds.jl")

include("MathProg/buffer.jl")
include("MathProg/formulations.jl")
include("MathProg/types.jl")
include("MathProg/variables.jl")
include("MathProg/bounds.jl")

include("variable.jl")
include("constraint.jl")

function unit_tests()
    @testset "ColunaBase submodule" begin
        nestedenum_unit()
        bound_unit()
        solution_unit()
    end

    @testset "MathProg submodule" begin
        buffer_tests()
        max_nb_form_unit()
        types_unit_tests()
        variables_unit_tests()
        mathprog_bounds()
    end

    @testset "variable.jl" begin
        variable_unit_tests()
    end
    
    @testset "constraint.jl" begin
        constraint_unit_tests()
    end

    return
end

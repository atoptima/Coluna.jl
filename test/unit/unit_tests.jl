include("containers/nestedenum.jl")
include("containers/solsandbounds.jl")

include("MathProg/types.jl")
include("MathProg/variables.jl")

include("algorithms/algorithm.jl")

# include("parameters.jl")
include("counters.jl")
include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("varconstr.jl")
# include("manager.jl")
include("optimizationresults.jl")
include("filters.jl")
include("incumbents.jl")
# include("formulation.jl")
# include("clone.jl")
# include("reformulation.jl")
# include("problem.jl")
# include("decomposition.jl")
# include("MOIinterface.jl")

# ###### Solvers & Strategies
# include("solvers/solver.jl")
# include("strategies/strategy.jl")
# include("solvers/colgen.jl")
# include("solvers/masteripheur.jl")
# # here include solvers
# include("solvers/interfaces.jl")
# include("strategies/mockstrategy.jl")
# # here include strategies

# ##### Search tree
# include("node.jl")
# include("bbtree.jl")

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

    @testset "vcids.jl" begin
        vcids_unit_tests()
    end

    @testset "variable.jl" begin
        variable_unit_tests()
    end
    @testset "constraint.jl" begin
        constraint_unit_tests()
    end
    @testset "varconstr.jl" begin
        varconstr_unit_tests()
    end
    @testset "optimizationresults.jl" begin
        optimizationresults_unit_test()
    end
    @testset "incumbents.jl" begin
        incumbents_unit_tests()
    end
    @testset "filters.jl" begin
        filters_unit_tests()
    end

    return
end

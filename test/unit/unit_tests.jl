# include("types.jl")
# include("parameters.jl")
# include("counters.jl")
include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("varconstr.jl")
# include("manager.jl")
# include("filters.jl")
include("solsandbounds.jl")
# include("incumbents.jl")
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
    @testset "solsandbounds.jl" begin
        solsandbounds_unit_tests()
    end
    return
end

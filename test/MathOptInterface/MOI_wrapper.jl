# Testing guidelines for MOI : https://jump.dev/MathOptInterface.jl/v0.9.14/apimanual/#Testing-guideline-1

const OPTIMIZER = Coluna.Optimizer()
const CONFIG = MOIT.TestConfig(atol=1e-6, rtol=1e-6)


@testset "SolverName" begin
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "Coluna"
end

@testset "supports_default_copy_to" begin
    @test MOIU.supports_default_copy_to(OPTIMIZER, false)
    # Use `@test !...` if names are not supported
    @test MOIU.supports_default_copy_to(OPTIMIZER, true)
end

@testset "Unit" begin
    MOIT.unittest(OPTIMIZER, CONFIG, [
        "number_threads", # TODO : support of MOI.NumberOfThreads()
        "solve_qcp_edge_cases", # Quadratic constraints not supported
        "delete_nonnegative_variables", # variable deletion not supported
        "delete_variable", # variable deletion not supported
        "delete_variables", # variable deletion not supported
        "variablenames", # Coluna retrieves the name of the variable
        "silent", # TODO : support of MOI.Silent()
        "time_limit_sec", # TODO : support of MOI.TimeLimitSec()
        "delete_soc_variables", # soc variables not supported
        "solve_qp_edge_cases" # Quadratic objective not supported
    ])
end

# @testset "Modification" begin
#     MOIT.modificationtest(OPTIMIZER, CONFIG)
# end

@testset "Continuous Linear" begin
    MOIT.contlineartest(OPTIMIZER, CONFIG)
end




const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(Coluna.Optimizer)#, MOI.Silent() => true) # MOI.Silent not supported
const BRIDGED = MOI.instantiate(OPTIMIZER_CONSTRUCTOR, with_bridge_type = Float64)

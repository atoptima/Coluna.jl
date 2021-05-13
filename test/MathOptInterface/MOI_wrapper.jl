# Testing guidelines for MOI : https://jump.dev/MathOptInterface.jl/v0.9.14/apimanual/#Testing-guideline-1

const OPTIMIZER = Coluna.Optimizer()
MOI.set(OPTIMIZER, MOI.RawParameter("default_optimizer"), GLPK.Optimizer)

const CONFIG = MOIT.TestConfig(atol=1e-6, rtol=1e-6)


@testset "SolverName" begin
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "Coluna"
end

@testset "Kpis" begin
    data = CLD.GeneralizedAssignment.data("smallgap3.txt")

    coluna = JuMP.optimizer_with_attributes(
        CL.Optimizer,
        "params" => CL.Params(
            solver = ClA.TreeSearchAlgorithm(
                conqueralg = ClA.ColCutGenConquer(
                    colgen = ClA.ColumnGeneration(max_nb_iterations = 8)
                ), maxnumnodes = 4
            )
        ),
        "default_optimizer" => GLPK.Optimizer
    )

    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

    JuMP.optimize!(problem)

    @test MOI.get(problem, MOI.NodeCount()) == 4
    @test isa(MOI.get(problem, MOI.SolveTime()), Float64)
end

@testset "supports_default_copy_to" begin
    @test MOIU.supports_default_copy_to(OPTIMIZER, false)
    # Use `@test !...` if names are not supported
    @test MOIU.supports_default_copy_to(OPTIMIZER, true)
end

@testset "write_to_file" begin
    coluna = JuMP.optimizer_with_attributes(
        Coluna.Optimizer,
        "params" => CL.Params(solver=ClA.SolveIpForm()),
        "default_optimizer" => GLPK.Optimizer
    )
    model = BlockModel(coluna, direct_model=true)
    @variable(model, x)
    @constraint(model, x <= 1)
    @objective(model, Max, x)
    optimize!(model)

    dest = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_MPS)
    MOI.copy_to(dest, model)
    MOI.write_to_file(dest, "model.mps")

    filedata = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_MPS)
    MOI.read_from_file(filedata, "model.mps")

    model2 = BlockModel(coluna, direct_model=true)
    MOI.copy_to(model2, filedata)
    optimize!(model2)

    # the model is always written as a minimization problem
    @test JuMP.objective_value(model) == -JuMP.objective_value(model2)
end

const UNSUPPORTED_TESTS = [
    "solve_qcp_edge_cases", # Quadratic constraints not supported
    "delete_nonnegative_variables", # variable deletion not supported
    "delete_variable", # variable deletion not supported
    "delete_variables", # variable deletion not supported
    "variablenames", # Coluna retrieves the name of the variable
    "delete_soc_variables", # soc variables not supported
    "solve_qp_edge_cases", # Quadratic objective not supported
    "solve_affine_deletion_edge_cases", # VectorAffineFunction not supported
    "solve_affine_interval", # ScalarAffineFunction`-in-`Interval` not supported
    "solve_duplicate_terms_vector_affine", # VectorAffineFunction not supported
    "update_dimension_nonnegative_variables", # VectorAffineFunction not supported
    "solve_farkas_interval_upper", # ScalarAffineFunction`-in-`Interval` not supported
    "solve_farkas_interval_lower", # ScalarAffineFunction`-in-`Interval` not supported
    "solve_result_index", # Quadratic objective not supported
    "get_objective_function", # Quandratic objective not supported
    "number_threads", # TODO : support of MOI.NumberOfThreads()
    "silent", # TODO : support of MOI.Silent()
    "time_limit_sec", # TODO : support of MOI.TimeLimitSec()
    "solve_time", # TODO : support of MOI.SolveTime()
    "solve_twice" # TODO : fix 
]

MathOptInterface.Test.getconstraint
const BASIC = [
    "add_variable",
    "solver_name",
    "add_variables",
    "feasibility_sense",
    "max_sense",
    "min_sense",
    "getvariable",
    "getconstraint"
]

const MIP_TESTS = [
    "solve_zero_one_with_bounds_1",
    "solve_zero_one_with_bounds_2",
    "solve_zero_one_with_bounds_3",
    "solve_integer_edge_cases",
    "solve_objbound_edge_cases"
]

const LP_TESTS = [
    "solve_with_lowerbound",
    "solve_affine_greaterthan",
    "solve_singlevariable_obj",
    "solve_unbounded_model",
    "solve_constant_obj",
    "solve_single_variable_dual_max",
    "solve_single_variable_dual_min",
    "solve_duplicate_terms_obj",
    "raw_status_string",
    "solve_affine_equalto",
    "solve_farkas_lessthan",
    "solve_farkas_greaterthan",
    "solve_blank_obj",
    "solve_with_upperbound",
    "solve_farkas_variable_lessthan_max",
    "solve_farkas_variable_lessthan",
    "solve_farkas_equalto_upper",
    "solve_farkas_equalto_lower",
    "solve_farkas_equalto_lower",
    "solve_duplicate_terms_scalar_affine",
    "solve_affine_lessthan"
]

@testset "Unit Basic/MIP" begin
    MOI.set(OPTIMIZER, MOI.RawParameter("params"), CL.Params(solver = ClA.SolveIpForm()))
    MOIT.unittest(OPTIMIZER, CONFIG, vcat(UNSUPPORTED_TESTS, LP_TESTS, MIP_TESTS))
    MOIT.unittest(OPTIMIZER, CONFIG, vcat(UNSUPPORTED_TESTS, LP_TESTS, BASIC))
end

# @testset "Integer Linear" begin
#     MOIT.intlineartest(OPTIMIZER, CONFIG, [
#         "indicator1", "indicator2", "indicator3", "indicator4", # indicator constraints not supported
#         "semiconttest", "semiinttest", # semi integer vars not supported
#         "int2" # SOS1 & SOS2 not supported
#     ])
# end

# @testset "Unit LP" begin
#     MOI.set(OPTIMIZER, MOI.RawParameter("params"), CL.Params(solver = ClA.SolveLpForm()))
#     MOIT.unittest(OPTIMIZER, CONFIG, vcat(UNSUPPORTED_TESTS, MIP_TESTS, BASIC))
# end

# @testset "Continuous Linear" begin
#     MOIT.contlineartest(OPTIMIZER, CONFIG, [
#         "partial_start" # VariablePrimalStart not supported
#     ])
# end

const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(Coluna.Optimizer)#, MOI.Silent() => true) # MOI.Silent not supported
const BRIDGED = MOI.instantiate(OPTIMIZER_CONSTRUCTOR, with_bridge_type = Float64)

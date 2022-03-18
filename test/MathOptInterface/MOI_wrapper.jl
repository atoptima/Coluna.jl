
# ============================ /test/MOI_wrapper.jl ============================
module TestColuna

import Coluna
using MathOptInterface
using Test
using HiGHS

const MOI = MathOptInterface

const OPTIMIZER = MOI.instantiate(
    MOI.OptimizerWithAttributes(
        Coluna.Optimizer, 
        MOI.RawOptimizerAttribute("default_optimizer") => HiGHS.Optimizer,
        MOI.RawOptimizerAttribute("params") => Coluna.Params(
            solver = Coluna.Algorithm.SolveIpForm(
                moi_params = Coluna.Algorithm.MoiOptimize(get_dual_solution = true)
            )
        )
    ),
)

const BRIDGED = MOI.instantiate(
    MOI.OptimizerWithAttributes(
        Coluna.Optimizer,
        MOI.RawOptimizerAttribute("default_optimizer") => HiGHS.Optimizer,
        MOI.RawOptimizerAttribute("params") => Coluna.Params(
            solver = Coluna.Algorithm.SolveIpForm(
                moi_params = Coluna.Algorithm.MoiOptimize(get_dual_solution = true)
            )
        )
    ),
    with_bridge_type = Float64,
)

# See the docstring of MOI.Test.Config for other arguments.
const CONFIG = MOI.Test.Config(
    # Modify tolerances as necessary.
    atol = 1e-6,
    rtol = 1e-6,
    # Use MOI.LOCALLY_SOLVED for local solvers.
    optimal_status = MOI.OPTIMAL,
    # Pass attributes or MOI functions to `exclude` to skip tests that
    # rely on this functionality.
    exclude = Any[MOI.VariableName, MOI.delete],
)

"""
    runtests()

This function runs all functions in the this Module starting with `test_`.
"""
function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
getfield(@__MODULE__, name)()
            end
        end
    end
end

"""
    test_runtests()

This function runs all the tests in MathOptInterface.Test.

Pass arguments to `exclude` to skip tests for functionality that is not
implemented or that your solver doesn't support.
"""
function test_runtests()
    MOI.Test.runtests(
        BRIDGED,
        CONFIG,
        # include = [
        #     # ##"test_linear_DUAL_INFEASIBLE",
        #     # ##"test_linear_DUAL_INFEASIBLE_2",
        #     # ##"test_linear_FEASIBILITY_SENSE",
        #     # ##"test_linear_INFEASIBLE",
        #     # ##"test_linear_INFEASIBLE_2",
        #     # "test_linear_Interval_inactive",
        #     # ##"test_linear_LessThan_and_GreaterThan",
        #     # ##"test_linear_Semicontinuous_integration",
        #     # ##"test_linear_Semiinteger_integration",
        #     # ##"test_linear_VectorAffineFunction",
        #     # "test_linear_VectorAffineFunction_empty_row",
        #     # "test_linear_add_constraints",
        #     # "test_linear_inactive_bounds",
        #     # ##"test_linear_integer_integration",
        #     # ##"test_linear_integer_knapsack",
        #     # ##"test_linear_integer_solve_twice",
        #     "test_linear_integration",
        #     "test_linear_integration_2",
        #     # "test_linear_integration_Interval",
        #     # "test_linear_integration_delete_variables",
        #     # ##"test_linear_integration_modification",
        #     # ##"test_linear_modify_GreaterThan_and_LessThan_constraints",
        #     # "test_linear_transform",
        # ],
        exclude = [
            "test_attribute_NumberOfThreads",
            "test_quadratic_",
            "test_conic_",
            # We have to fix the following tests (or keep them excluded and explain why):
            "test_constraint_ScalarAffineFunction_Interval", # TODO
            "test_modification_transform_singlevariable_lessthan", # old and new variable share same id -> problem in buffer...
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            "test_attribute_SolverVersion",   
            "test_nonlinear_",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_EqualTo_lower",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_EqualTo_upper",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_GreaterThan",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_Interval_lower",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_Interval_upper",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_LessThan",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_VariableIndex_LessThan",
            "test_solve_DualStatus_INFEASIBILITY_CERTIFICATE_VariableIndex_LessThan_max",
            "test_solve_ObjectiveBound_MAX_SENSE_IP",
            "test_solve_ObjectiveBound_MAX_SENSE_LP",
            "test_solve_ObjectiveBound_MIN_SENSE_IP",
            "test_solve_ObjectiveBound_MIN_SENSE_LP",
            "test_solve_TerminationStatus_DUAL_INFEASIBLE",
            "test_solve_VariableIndex_ConstraintDual_MAX_SENSE",
            "test_solve_VariableIndex_ConstraintDual_MIN_SENSE",
            "test_solve_optimize_twice",
            "test_solve_result_index"
        ],
        # This argument is useful to prevent tests from failing on future
        # releases of MOI that add new tests. Don't let this number get too far
        # behind the current MOI release though! You should periodically check
        # for new tests in order to fix bugs and implement new features.
        exclude_tests_after = v"0.10.5",
    )
    return
end

"""
    test_SolverName()

You can also write new tests for solver-specific functionality. Write each new
test as a function with a name beginning with `test_`.
"""
function test_SolverName()
    @test MOI.get(Coluna.Optimizer(), MOI.SolverName()) == "Coluna"
    return
end

end # module TestColuna

# This line at tne end of the file runs all the tests!
TestColuna.runtests()

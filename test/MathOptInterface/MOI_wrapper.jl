
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
        #     "test_constraint_ScalarAffineFunction_EqualTo",
        #     "test_constraint_ScalarAffineFunction_GreaterThan",
        #     "test_constraint_ScalarAffineFunction_Interval",
        #     "test_constraint_ScalarAffineFunction_LessThan",
        #     "test_constraint_ScalarAffineFunction_duplicate",
        #     "test_constraint_VectorAffineFunction_duplicate",
        #     "test_constraint_ZeroOne_bounds",
        #     "test_constraint_ZeroOne_bounds_2",
        #     "test_constraint_ZeroOne_bounds_3",
        #     "test_constraint_get_ConstraintIndex"
        # ],
        exclude = [
            "test_attribute_NumberOfThreads",
            "test_quadratic_",
            # We have to fix the following tests (or keep them excluded and explain why):
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            "test_attribute_SolverVersion",   
            "test_conic_",
            "test_linear_DUAL_INFEASIBLE",
            "test_linear_DUAL_INFEASIBLE_2",
            "test_linear_FEASIBILITY_SENSE",
            "test_linear_INFEASIBLE",
            "test_linear_INFEASIBLE_2",
            "test_linear_Interval_inactive",
            "test_linear_LessThan_and_GreaterThan",
            "test_linear_Semicontinuous_integration",
            "test_linear_Semiinteger_integration",
            "test_linear_VectorAffineFunction",
            "test_linear_VectorAffineFunction_empty_row",
            "test_linear_add_constraints",
            "test_linear_inactive_bounds",
            "test_linear_integer_integration",
            "test_linear_integer_knapsack",
            "test_linear_integer_solve_twice",
            "test_linear_integration",
            "test_linear_integration_2",
            "test_linear_integration_Interval",
            "test_linear_integration_delete_variables",
            "test_linear_integration_modification",
            "test_linear_modify_GreaterThan_and_LessThan_constraints",
            "test_linear_transform",
            "test_model_ListOfConstraintAttributesSet",
            "test_model_ModelFilter_ListOfConstraintIndices",
            "test_model_ModelFilter_ListOfConstraintTypesPresent",
            "test_model_Name_VariableName_ConstraintName",
            "test_model_ScalarAffineFunction_ConstraintName",
            "test_model_ScalarFunctionConstantNotZero",
            "test_model_UpperBoundAlreadySet",
            "test_model_VariableIndex_ConstraintName",
            "test_model_VariableName",
            "test_model_copy_to_UnsupportedAttribute",
            "test_model_copy_to_UnsupportedConstraint",
            "test_model_duplicate_ScalarAffineFunction_ConstraintName",
            "test_model_duplicate_VariableName",
            "test_model_empty",
            "test_modification_affine_deletion_edge_cases",
            "test_modification_coef_scalar_objective",
            "test_modification_coef_scalaraffine_lessthan",
            "test_modification_const_scalar_objective",
            "test_modification_const_vectoraffine_nonpos",
            "test_modification_delete_variable_with_single_variable_obj",
            "test_modification_delete_variables_in_a_batch",
            "test_modification_func_scalaraffine_lessthan",
            "test_modification_func_vectoraffine_nonneg",
            "test_modification_multirow_vectoraffine_nonpos",
            "test_modification_set_scalaraffine_lessthan",
            "test_modification_set_singlevariable_lessthan",
            "test_modification_transform_singlevariable_lessthan",
            "test_nonlinear_Feasibility_internal",
            "test_objective_FEASIBILITY_SENSE_clears_objective",
            "test_objective_ObjectiveFunction_VariableIndex",
            "test_objective_ObjectiveFunction_blank",
            "test_objective_ObjectiveFunction_constant",
            "test_objective_ObjectiveFunction_duplicate_terms",
            "test_objective_get_ObjectiveFunction_ScalarAffineFunction",
            "test_objective_set_via_modify",
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
            "test_solve_result_index",
            "test_variable_VariableName",
            "test_variable_delete_Nonnegatives",
            "test_variable_delete_Nonnegatives_row",
            "test_variable_get_VariableIndex",
            "test_variable_solve_Integer_with_lower_bound",
            "test_variable_solve_Integer_with_upper_bound",
            "test_variable_solve_ZeroOne_with_0_upper_bound",
            "test_variable_solve_ZeroOne_with_upper_bound",
            "test_variable_solve_with_lowerbound",
            "test_variable_solve_with_upperbound"
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

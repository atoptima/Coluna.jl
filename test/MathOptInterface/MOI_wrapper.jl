
# ============================ /test/MOI_wrapper.jl ============================
module TestColuna

import Coluna
using MathOptInterface
using Test
using HiGHS

const MOI = MathOptInterface

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
        exclude = [
            "test_attribute_NumberOfThreads",
            "test_quadratic_",
            "test_conic_",
            "test_nonlinear_",
            "test_cpsat_",
            # Unsupported attributes
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            # Following tests needs support of variable basis.
            "test_linear_Interval_inactive",
            "test_linear_add_constraints",
            "test_linear_inactive_bounds",
            "test_linear_integration_2",
            "test_linear_integration_Interval",
            "test_linear_integration_delete_variables",
            "test_linear_transform",
            # To see later if we need to support SOS2 integration
            "test_linear_SOS2_integration",
            # To see if we can support this tests, they fail because
            # MethodError: no method matching _is_valid(::Type{MathOptInterface.Semicontinuous{Float64}}, ::Coluna._VarBound, ::Coluna._VarBound, ::Coluna._VarKind)
            "test_basic_ScalarAffineFunction_Semicontinuous",
            "test_basic_ScalarAffineFunction_Semiinteger",
            "test_basic_VariableIndex_Semicontinuous",
            "test_basic_VariableIndex_Semiinteger",
        ],
        # This argument is useful to prevent tests from failing on future
        # releases of MOI that add new tests. Don't let this number get too far
        # behind the current MOI release though! You should periodically check
        # for new tests in order to fix bugs and implement new features.
        exclude_tests_after = v"1.14.0",
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

# This line at the end of the file runs all the tests!
TestColuna.runtests()

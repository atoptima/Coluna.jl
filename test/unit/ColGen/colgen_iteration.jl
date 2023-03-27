# Test using the column generation example for Integer Programming book by Wolsey
# See page 191.

# There is no so much logic to test in the generic implementation of an iteration of column
# generation:
# - calculation of reduced costs
# - calculation of the master lp dual bound
# - flow
# - error handling
# - output

# This is the problems that we consider here:
#         master
#             min
#             7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45 + 28λ1 + 25λ2 + 21λ3 + 19λ4 + 22λ5 + 18λ6 + 28λ7
#             s.t.
#             x_12 + x_13 + x_14 + x_15 + 2λ1 + 2λ2 + 2λ3 + 2λ4 + 2λ5 + 2λ6 + 2λ7 == 2
#             x_12 + x_23 + x_24 + x_25 + 2λ1 + 2λ2 + 2λ3 + 1λ4 + 1λ5 + 2λ6 + 3λ7 == 2
#             x_13 + x_23 + x_34 + x_35 + 2λ1 + 3λ2 + 2λ3 + 3λ4 + 2λ5 + 3λ6 + 1λ7 == 2
#             x_14 + x_24 + x_34 + x_45 + 2λ1 + 2λ2 + 3λ3 + 3λ4 + 3λ5 + 1λ6 + 1λ7 == 2
#             x_15 + x_25 + x_35 + x_45 + 2λ1 + 1λ2 + 1λ3 + 1λ4 + 2λ5 + 2λ6 + 3λ7 == 2

#         dw_sp
#             min
#             7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45
#             s.t.
#             x_12 + x_13 + x_14 + x_15 == 1

#         continuous
#             columns
#                 λ1, λ2, λ3, λ4, λ5, λ6, λ7

#         integer
#             representatives
#                 x_12, x_13, x_14, x_15, x_23, x_24, x_25, x_34, x_35, x_45

#         bounds
#             λ1 >= 0
#             λ2 >= 0
#             λ3 >= 0
#             λ4 >= 0
#             λ5 >= 0
#             λ6 >= 0
#             λ7 >= 0
#             x_12 >= 0
#             x_13 >= 0
#             x_14 >= 0
#             x_15 >= 0
#             x_23 >= 0
#             x_24 >= 0
#             x_25 >= 0
#             x_34 >= 0
#             x_35 >= 0
#             x_45 >= 0

struct ColGenIterationTestMaster end
struct ColGenIterationTestPricing end
struct ColGenIterationTestReform end

# Column generation context
# We have many flags here to test lots of different scenarios that might happens if
# we there is a bug in the subsolver or MOI.
Base.@kwdef struct ColGenIterationTestContext <: ColGen.AbstractColGenContext
    master_term_status::ClB.TerminationStatus = ClB.OPTIMAL
    master_solver_has_no_primal_solution::Bool = false
    master_solver_has_no_dual_solution::Bool = false
    pricing_term_status::ClB.TerminationStatus = ClB.OPTIMAL
    pricing_has_correct_dual_bound::Bool = true
    pricing_has_incorrect_dual_bound::Bool = false  
    pricing_has_no_dual_bound::Bool = false 
    pricing_solver_has_no_solution::Bool = false
    reform = ColGenIterationTestReform()
    master = ColGenIterationTestMaster()
    pricing = ColGenIterationTestPricing()
end
ColGen.get_master(ctx::ColGenIterationTestContext) = ctx.master
ColGen.get_reform(ctx::ColGenIterationTestContext) = ctx.reform
ColGen.get_pricing_subprobs(context) = [(1, context.pricing)]

# Pricing strategy
struct ColGenIterationTestPricingStrategy <: ColGen.AbstractPricingStrategy
    subprobs::Vector{Tuple{Int, ColGenIterationTestPricing}}
end
ColGen.get_pricing_strategy(context::ColGenIterationTestContext, _) = ColGenIterationTestPricingStrategy(ColGen.get_pricing_subprobs(context))
ColGen.pricing_strategy_iterate(strategy::ColGenIterationTestPricingStrategy) = iterate(strategy.subprobs)
ColGen.pricing_strategy_iterate(strategy::ColGenIterationTestPricingStrategy, state) = iterate(strategy.subprobs, state)

# Column generation phase
struct ColGenIterationTestPhase <: ColGen.AbstractColGenPhase end

# Master 
struct ColGenIterationTestMasterResult
    term_status::ClB.TerminationStatus
    obj_val::Union{Nothing,Float64}
    primal_sol::Union{Nothing, Vector{Float64}}
    dual_sol::Union{Nothing, Vector{Float64}}
end
ColGen.get_primal_sol(res::ColGenIterationTestMasterResult) = res.primal_sol
ColGen.get_dual_sol(res::ColGenIterationTestMasterResult) = res.dual_sol
ColGen.get_obj_val(res::ColGenIterationTestMasterResult) = res.obj_val
ColGen.is_infeasible(res::ColGenIterationTestMasterResult) = res.term_status == ClB.INFEASIBLE
ColGen.is_unbounded(res::ColGenIterationTestMasterResult) = res.term_status == ClB.DUAL_INFEASIBLE
ColGen.is_optimal(res::ColGenIterationTestMasterResult) = res.term_status == ClB.OPTIMAL

## mock of the master lp solver
function ColGen.optimize_master_lp_problem!(master, ctx::ColGenIterationTestContext, env)
    obj_val = nothing
    primal_sol = nothing
    dual_sol = nothing
    if ctx.master_term_status == ClB.OPTIMAL
        obj_val = 22.5
        primal_sol = [0, 0, 1/4, 0, 1/4, 1/4, 1/4]
        dual_sol = [151/8, -1, -11/2, -5/4, 0]
    end
    return ColGenIterationTestMasterResult(ctx.master_term_status, obj_val, primal_sol, dual_sol)
end

# Pricing
struct ColGenIterationTestPricingResult
    term_status::ClB.TerminationStatus
    primal_sols::Vector{Vector{Float64}}
    primal_bound::Union{Nothing, Float64}
    dual_bound::Union{Nothing, Float64}
end
ColGen.get_primal_sols(res::ColGenIterationTestPricingResult) = res.primal_sols
ColGen.get_dual_bound(res::ColGenIterationTestPricingResult) = res.dual_bound
ColGen.compute_sp_init_db(::ColGenIterationTestContext, sp) = -Inf
ColGen.set_of_columns(::ColGenIterationTestContext) = Vector{Float64}[]
ColGen.push_in_set!(set::Vector{Vector{Float64}}, col::Vector) = push!(set, col)
ColGen.is_infeasible(res::ColGenIterationTestPricingResult) = res.term_status == ClB.INFEASIBLE
ColGen.is_unbounded(res::ColGenIterationTestPricingResult) = res.term_status == ClB.DUAL_INFEASIBLE
ColGen.is_optimal(res::ColGenIterationTestPricingResult) = res.term_status == ClB.OPTIMAL

## mock of the pricing solver
function ColGen.optimize_pricing_problem!(ctx::ColGenIterationTestContext, form, env, master_dual_sol)
    primal_val = nothing
    dual_val = nothing
    sols = Vector{Float64}[]

    if !ctx.pricing_solver_has_no_solution
        push!(sols, [0, 1, 1, 0, 1, 1, 0, 0, 1, 0])
        primal_val = -23/4
    end

    if ctx.pricing_has_correct_dual_bound
        dual_val = -23/4
    elseif ctx.pricing_has_incorrect_dual_bound
        dual_val = -47 # this value is lower than the correct dual bound (minimization problem!!)
    else
        @assert ctx.pricing_has_no_dual_bound
    end
    return ColGenIterationTestPricingResult(ctx.pricing_term_status, sols, primal_val, dual_val)
end

# Reduced costs
ColGen.get_subprob_var_orig_costs(::ColGenIterationTestContext) = [7, 2, 1, 5, 3, 6, 8, 4, 2, 9]
ColGen.get_subprob_var_coef_matrix(::ColGenIterationTestContext) = [
    1 1 1 1 0 0 0 0 0 0; 
    1 0 0 0 1 1 1 0 0 0; 
    0 1 0 0 1 0 0 1 1 0; 
    0 0 1 0 0 1 0 1 0 1; 
    0 0 0 1 0 0 1 0 1 1
]
function ColGen.update_sp_vars_red_costs!(::ColGenIterationTestContext, subprob, red_costs)
    # We check that reduced costs are correct.
    @test reduce(&, red_costs .== [-87/8, -91/8, -133/8, -111/8, 19/2, 33/4, 9, 43/4, 15/2, 41/4])
    return
end

ColGen.check_primal_ip_feasibility(::ColGenIterationTestPhase, sol, reform) = nothing
ColGen.update_master_constrs_dual_vals!(::ColGenIterationTestContext, ::ColGenIterationTestPhase, reform, dual_mast_sol) = nothing

function ColGen.insert_columns!(reform, ::ColGenIterationTestContext, phase, generated_columns)
    @test length(generated_columns) == 1
    @test generated_columns[1] == [0, 1, 1, 0, 1, 1, 0, 0, 1, 0]
    return 1
end

function ColGen.compute_dual_bound(::ColGenIterationTestContext, ::ColGenIterationTestPhase, mast_lp_obj_val, sp_dbs, mast_dual_sol)
    return 22.5 - 23/4
end

function colgen_iteration_master_ok_pricing_ok()
    ctx = ColGenIterationTestContext()
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), nothing)
    @test output.mlp == 22.5
    @test output.db == 22.5 - 23/4
    @test output.nb_new_cols == 1
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_iteration", colgen_iteration_master_ok_pricing_ok)

function colgen_iteration_master_infeasible()
    ctx = ColGenIterationTestContext(
        master_term_status = ClB.INFEASIBLE,
        master_solver_has_no_primal_solution = true,
        master_solver_has_no_dual_solution = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), nothing)
    @test isnothing(output.mlp)
    @test output.db == Inf 
    @test output.nb_new_cols == 0
    @test output.infeasible_master == true
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_iteration", colgen_iteration_master_infeasible)

function colgen_iteration_pricing_infeasible()
    ctx = ColGenIterationTestContext(
        pricing_term_status = ClB.INFEASIBLE,
        pricing_solver_has_no_solution = true,
        pricing_has_no_dual_bound = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), nothing)
    @test isnothing(output.mlp)
    @test output.db == Inf
    @test output.nb_new_cols == 0
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == true
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_iteration", colgen_iteration_pricing_infeasible)

function colgen_iteration_master_unbounded()
    ctx = ColGenIterationTestContext(
        master_term_status = ClB.DUAL_INFEASIBLE,
        master_solver_has_no_primal_solution = true,
        master_solver_has_no_dual_solution = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), nothing)
    @test output.mlp == -Inf
    @test isnothing(output.db)
    @test output.nb_new_cols == 0
    @test output.infeasible_master == false
    @test output.unbounded_master == true
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
end
register!(unit_tests, "colgen_iteration", colgen_iteration_master_unbounded)

function colgen_iteration_pricing_unbounded()
    ctx = ColGenIterationTestContext(
        pricing_term_status = ClB.DUAL_INFEASIBLE,
        pricing_solver_has_no_solution = true,
        pricing_has_no_dual_bound = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), nothing)
    @test isnothing(output.mlp)
    @test isnothing(output.db)
    @test output.nb_new_cols == 0
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == true
end
register!(unit_tests, "colgen_iteration", colgen_iteration_pricing_unbounded)

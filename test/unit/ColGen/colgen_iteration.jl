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
    new_ip_primal_sol::Bool = false
    master_has_new_cuts::Bool = false
    reform = ColGenIterationTestReform()
    master = ColGenIterationTestMaster()
    pricing = ColGenIterationTestPricing()
end
ColGen.get_master(ctx::ColGenIterationTestContext) = ctx.master
ColGen.get_reform(ctx::ColGenIterationTestContext) = ctx.reform
ColGen.is_minimization(ctx::ColGenIterationTestContext) = true
ColGen.get_pricing_subprobs(context) = [(1, context.pricing)]
ColGen.colgen_iteration_output_type(::ColGenIterationTestContext) = ClA.ColGenIterationOutput
ColGen.colgen_phase_output_type(::ColGenIterationTestContext) = ClA.ColGenPhaseOutput

# Stage
struct ColGenIterationTestStage <: ColGen.AbstractColGenStage end
ColGen.get_pricing_subprob_optimizer(::ColGenIterationTestStage, _) = 1
ColGen.is_exact_stage(::ColGenIterationTestStage) = true

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
ColGen.is_unbounded(res::ColGenIterationTestMasterResult) = res.term_status == ClB.UNBOUNDED

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
ColGen.get_primal_bound(res::ColGenIterationTestPricingResult) = res.primal_bound
ColGen.get_dual_bound(res::ColGenIterationTestPricingResult) = res.dual_bound
ColGen.compute_sp_init_db(::ColGenIterationTestContext, sp) = -Inf
ColGen.compute_sp_init_pb(::ColGenIterationTestContext, sp) = Inf
ColGen.set_of_columns(::ColGenIterationTestContext) = Vector{Float64}[]
ColGen.is_infeasible(res::ColGenIterationTestPricingResult) = res.term_status == ClB.INFEASIBLE
ColGen.is_unbounded(res::ColGenIterationTestPricingResult) = res.term_status == ClB.UNBOUNDED

function ColGen.push_in_set!(ctx::ColGenIterationTestContext, set::Vector{Vector{Float64}}, col::Vector)
    push!(set, col)
    return true 
end

## mock of the pricing solver
function ColGen.optimize_pricing_problem!(ctx::ColGenIterationTestContext, form, env, optimizer, master_dual_sol, stab_changes_mast_dual_sol)
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

ColGen.update_reduced_costs!(::ColGenIterationTestContext, phase, red_costs) = nothing

function ColGen.check_primal_ip_feasibility!(sol, ctx::ColGenIterationTestContext, ::ColGenIterationTestPhase, env)
    if ctx.new_ip_primal_sol
        @assert !ctx.master_has_new_cuts
        return [7.0, 7.0, 7.0], false
    end
    if ctx.master_has_new_cuts
        @assert !ctx.new_ip_primal_sol
        return nothing, true
    end
    return nothing, false
end

ColGen.is_better_primal_sol(::Vector{Float64}, ::Nothing) = true
ColGen.is_better_primal_sol(::Vector{Float64}, ::Vector{Float64}) = false

function ColGen.update_inc_primal_sol!(::ColGenIterationTestContext, sol::Vector{Float64})
    @test sol == [7.0, 7.0, 7.0]
end

ColGen.update_master_constrs_dual_vals!(::ColGenIterationTestContext, dual_mast_sol) = nothing

function ColGen.insert_columns!(::ColGenIterationTestContext, phase, generated_columns)
    @test length(generated_columns) == 1
    @test generated_columns[1] == [0, 1, 1, 0, 1, 1, 0, 0, 1, 0]
    return [1]
end

function ColGen.compute_dual_bound(::ColGenIterationTestContext, ::ColGenIterationTestPhase, sp_dbs, generated_columns, mast_dual_sol)
    return 22.5 - 23/4
end

ColGen.update_stabilization_after_pricing_optim!(::Coluna.Algorithm.NoColGenStab, ::ColGenIterationTestContext, _, _, _, _, _) = nothing

struct TestColGenIterationOutput <: ColGen.AbstractColGenIterationOutput
    min_sense::Bool
    mlp::Union{Nothing, Float64}
    db::Union{Nothing, Float64}
    nb_new_cols::Int
    new_cut_in_master::Bool
    infeasible_master::Bool
    unbounded_master::Bool
    infeasible_subproblem::Bool
    unbounded_subproblem::Bool
    time_limit_reached::Bool
    master_lp_primal_sol::Union{Nothing, Vector{Float64}}
    master_ip_primal_sol::Union{Nothing, Vector{Float64}}
    master_lp_dual_sol::Union{Nothing, Vector{Float64}}
end

ColGen.colgen_iteration_output_type(::ColGenIterationTestContext) = TestColGenIterationOutput

function ColGen.new_iteration_output(::Type{<:TestColGenIterationOutput}, 
    min_sense,
    mlp,
    db,
    nb_new_cols,
    new_cut_in_master,
    infeasible_master,
    unbounded_master,
    infeasible_subproblem,
    unbounded_subproblem,
    time_limit_reached,
    master_lp_primal_sol,
    master_ip_primal_sol,
    master_lp_dual_sol
)
    return TestColGenIterationOutput(
        min_sense,
        mlp,
        db,
        nb_new_cols,
        new_cut_in_master,
        infeasible_master,
        unbounded_master,
        infeasible_subproblem,
        unbounded_subproblem,
        time_limit_reached,
        master_lp_primal_sol,
        master_ip_primal_sol,
        master_lp_dual_sol
    )
end

ColGen.update_stabilization_after_pricing_optim!(::Coluna.Algorithm.NoColGenStab, ::TestColGenIterationContext, _, _, _, _, _) = nothing


function colgen_iteration_master_ok_pricing_ok()
    ctx = ColGenIterationTestContext()
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
    @test output.mlp == 22.5
    @test output.db == 22.5 - 23/4
    @test output.nb_new_cols == 1
    @test output.new_cut_in_master == false
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
    @test isnothing(output.master_ip_primal_sol)
end
register!(unit_tests, "colgen_iteration", colgen_iteration_master_ok_pricing_ok)

function colgen_iteration_master_infeasible()
    ctx = ColGenIterationTestContext(
        master_term_status = ClB.INFEASIBLE,
        master_solver_has_no_primal_solution = true,
        master_solver_has_no_dual_solution = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
    @test isnothing(output.mlp)
    @test output.db == Inf 
    @test output.nb_new_cols == 0
    @test output.new_cut_in_master == false
    @test output.infeasible_master == true
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
    @test isnothing(output.master_ip_primal_sol)
end
register!(unit_tests, "colgen_iteration", colgen_iteration_master_infeasible)

function colgen_iteration_pricing_infeasible()
    ctx = ColGenIterationTestContext(
        pricing_term_status = ClB.INFEASIBLE,
        pricing_solver_has_no_solution = true,
        pricing_has_no_dual_bound = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
    @test isnothing(output.mlp)
    @test output.db == Inf
    @test output.nb_new_cols == 0
    @test output.new_cut_in_master == false
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == true
    @test output.unbounded_subproblem == false
    @test isnothing(output.master_ip_primal_sol)
end
register!(unit_tests, "colgen_iteration", colgen_iteration_pricing_infeasible)

function colgen_iteration_master_unbounded()
    ctx = ColGenIterationTestContext(
        master_term_status = ClB.UNBOUNDED,
        master_solver_has_no_primal_solution = true,
        master_solver_has_no_dual_solution = true
    )
    @test_throws ColGen.UnboundedProblemError ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
end
register!(unit_tests, "colgen_iteration", colgen_iteration_master_unbounded)

function colgen_iteration_pricing_unbounded()
    ctx = ColGenIterationTestContext(
        pricing_term_status = ClB.UNBOUNDED,
        pricing_solver_has_no_solution = true,
        pricing_has_no_dual_bound = true
    )
    @test_throws ColGen.UnboundedProblemError ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
end
register!(unit_tests, "colgen_iteration", colgen_iteration_pricing_unbounded)

function colgen_finds_ip_primal_sol()
    ctx = ColGenIterationTestContext(
        new_ip_primal_sol = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
    @test output.mlp == 22.5
    @test output.db == 22.5 - 23/4
    @test output.nb_new_cols == 1
    @test output.new_cut_in_master == false
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
    @test output.master_ip_primal_sol == [7.0, 7.0, 7.0]
end
register!(unit_tests, "colgen_iteration", colgen_finds_ip_primal_sol)

function colgen_new_cuts_in_master()
    ctx = ColGenIterationTestContext(
        master_has_new_cuts = true
    )
    output = ColGen.run_colgen_iteration!(ctx, ColGenIterationTestPhase(), ColGenIterationTestStage(), nothing, nothing, Coluna.Algorithm.NoColGenStab())
    @test isnothing(output.mlp)
    @test isnothing(output.db)
    @test output.nb_new_cols == 0
    @test output.new_cut_in_master == true
    @test output.infeasible_master == false
    @test output.unbounded_master == false
    @test output.infeasible_subproblem == false
    @test output.unbounded_subproblem == false
    @test isnothing(output.master_ip_primal_sol)
end
register!(unit_tests, "colgen_iteration", colgen_new_cuts_in_master)

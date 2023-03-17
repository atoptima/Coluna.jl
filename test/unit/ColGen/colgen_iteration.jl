# Test using the column generation example for Integer Programming book by Wolsey
# See page 191.

# There is no so much logic to test in the generic implementation of an iteration of column
# generation:
# - calculation of reduced costs
# - calculation of the master lp dual bound
# - flow
# - error handling
# - output

function get_reform_master_and_vars_colgen_iteration()
    form_string1 = """
        master
            min
            7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45 + 28λ1 + 25λ2 + 21λ3 + 19λ4 + 22λ5 + 18λ6 + 28λ7
            s.t.
            x_12 + x_13 + x_14 + x_15 + 2λ1 + 2λ2 + 2λ3 + 2λ4 + 2λ5 + 2λ6 + 2λ7 == 2
            x_12 + x_23 + x_24 + x_25 + 2λ1 + 2λ2 + 2λ3 + 1λ4 + 1λ5 + 2λ6 + 3λ7 == 2
            x_13 + x_23 + x_34 + x_35 + 2λ1 + 3λ2 + 2λ3 + 3λ4 + 2λ5 + 3λ6 + 1λ7 == 2
            x_14 + x_24 + x_34 + x_45 + 2λ1 + 2λ2 + 3λ3 + 3λ4 + 3λ5 + 1λ6 + 1λ7 == 2
            x_15 + x_25 + x_35 + x_45 + 2λ1 + 1λ2 + 1λ3 + 1λ4 + 2λ5 + 2λ6 + 3λ7 == 2

        dw_sp
            min
            7x_12 + 2x_13 + x_14 + 5x_15 + 3x_23 + 6x_24 + 8x_25 + 4x_34 + 2x_35 + 9x_45
            s.t.
            x_12 + x_13 + x_14 + x_15 == 1

        continuous
            columns
                λ1, λ2, λ3, λ4, λ5, λ6, λ7

        integer
            representatives
                x_12, x_13, x_14, x_15, x_23, x_24, x_25, x_34, x_35, x_45

        bounds
            λ1 >= 0
            λ2 >= 0
            λ3 >= 0
            λ4 >= 0
            λ5 >= 0
            λ6 >= 0
            λ7 >= 0
            x_12 >= 0
            x_13 >= 0
            x_14 >= 0
            x_15 >= 0
            x_23 >= 0
            x_24 >= 0
            x_25 >= 0
            x_34 >= 0
            x_35 >= 0
            x_45 >= 0
    """

    _, master, _, _, reform = reformfromstring(form_string1)
    vars_by_name = Dict{String, ClMP.Variable}(ClMP.getname(master, var) => var for (_, var) in ClMP.getvars(master))
    return reform, master, vars_by_name
end

# Column generation context
struct ColGenIterationTestContext <: ColGen.AbstractColGenContext
    master_term_status::ClB.TerminationStatus
    reform::ClMP.Reformulation
end
ColGen.get_master(ctx::ColGenIterationTestContext) = ClMP.getmaster(ctx.reform)
ColGen.get_reform(ctx::ColGenIterationTestContext) = ctx.reform
ColGen.get_pricing_subprobs(context) = ClMP.get_dw_pricing_sps(context.reform)

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
    primal_bound::Float64
    dual_bound::Float64
end
ColGen.get_primal_sols(res::ColGenIterationTestPricingResult) = res.primal_sols
ColGen.get_dual_bound(res::ColGenIterationTestPricingResult) = res.dual_bound
ColGen.compute_sp_init_db(::ColGenIterationTestContext, sp) = -Inf
ColGen.set_of_columns(::ColGenIterationTestContext) = Vector{Float64}[]
ColGen.push_in_set!(set, col) = push!(set, col)

## mock of the pricing solver
function ColGen.optimize_pricing_problem!(::ColGenIterationTestContext, form)
    return ColGenIterationTestPricingResult(ClB.OPTIMAL, [[0, 1, 1, 0, 1, 1, 0, 0, 1, 0]], -23/4, -23/4)
end

# Reduced costs
ColGen.get_orig_costs(::ColGenIterationTestContext) = [7, 2, 1, 5, 3, 6, 8, 4, 2, 9]
ColGen.get_coef_matrix(::ColGenIterationTestContext) = [
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

function run_colgen_iteration_test()
    reform, master, vars_by_name = get_reform_master_and_vars_colgen_iteration()

    mlp, db, ncols = ColGen.run_colgen_iteration!(ColGenIterationTestContext(ClB.OPTIMAL, reform), ColGenIterationTestPhase(), nothing)
    @test mlp == 22.5
    @test db == 22.5 - 23/4
    @test ncols == 1
end
register!(unit_tests, "colgen_iteration", run_colgen_iteration_test)
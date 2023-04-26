
struct TestColGenOutput <: ColGen.AbstractColGenPhaseOutput
    has_art_vars::Bool
    new_cuts_in_master::Bool
end
ClA.colgen_master_has_new_cuts(ctx::TestColGenOutput) = ctx.new_cuts_in_master
ClA.colgen_mast_lp_sol_has_art_vars(ctx::TestColGenOutput) = ctx.has_art_vars

# The two following tests are pretty straightforward.
# They are just here to make sure nobody changes the behavior of the phases.
function initial_phase_colgen_test()
    it = ClA.ColunaColGenPhaseIterator()
    @test ColGen.initial_phase(it) isa ClA.ColGenPhase3
end
register!(unit_tests, "colgen_phase", initial_phase_colgen_test)

function next_phase_colgen_test()
    it = ClA.ColunaColGenPhaseIterator()
    @test ColGen.next_phase(it, ClA.ColGenPhase3(), TestColGenOutput(true, false)) isa ClA.ColGenPhase1
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase3(), TestColGenOutput(false, false)))
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase1(), TestColGenOutput(true, false)))
    @test ColGen.next_phase(it, ClA.ColGenPhase1(), TestColGenOutput(false, false)) isa ClA.ColGenPhase2
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase2(), TestColGenOutput(true, false)))
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase2(), TestColGenOutput(false, false)))

    @test ColGen.next_phase(it, ClA.ColGenPhase1(), TestColGenOutput(false, true)) isa ClA.ColGenPhase1
    @test ColGen.next_phase(it, ClA.ColGenPhase2(), TestColGenOutput(false, true)) isa ClA.ColGenPhase2
    @test ColGen.next_phase(it, ClA.ColGenPhase3(), TestColGenOutput(false, true)) isa ClA.ColGenPhase3
end
register!(unit_tests, "colgen_phase", next_phase_colgen_test)

function get_reform_master_and_vars()
    form_string1 = """
        master
            min
            3x1 + 4x2 + 1000z
            s.t.
            x1 + x2 + z >= 1

        dw_sp
            min
            x1 + x2

        integer
            representatives
                x1, x2

        continuous
            artificial
                z
    """

    _, master, _, _, reform = reformfromstring(form_string1)
    vars_by_name = Dict{String, ClMP.Variable}(ClMP.getname(master, var) => var for (_, var) in ClMP.getvars(master))
    return reform, master, vars_by_name
end

function setup_reformulation_colgen_test()
    reform, master, vars_by_name = get_reform_master_and_vars()

    @test ClMP.getcurcost(master, vars_by_name["x1"]) == 3
    @test ClMP.getcurcost(master, vars_by_name["x2"]) == 4
    @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
    @test ClMP.iscuractive(master, vars_by_name["z"])

    ColGen.setup_reformulation!(reform, ClA.ColGenPhase1())
    @test ClMP.getcurcost(master, vars_by_name["x1"]) == 0
    @test ClMP.getcurcost(master, vars_by_name["x2"]) == 0
    @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
    @test ClMP.iscuractive(master, vars_by_name["z"])

    # To make sure that reduced costs will be well calculated:
    helper = ClA.ReducedCostsCalculationHelper(master)
    @test helper.master_c[ClMP.getid(vars_by_name["x1"])] == 0
    @test helper.master_c[ClMP.getid(vars_by_name["x2"])] == 0

    reform, master, vars_by_name = get_reform_master_and_vars()
    ColGen.setup_reformulation!(reform, ClA.ColGenPhase2())
    @test ClMP.getcurcost(master, vars_by_name["x1"]) == 3
    @test ClMP.getcurcost(master, vars_by_name["x2"]) == 4
    @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
    @test !ClMP.iscuractive(master, vars_by_name["z"])

    reform, master, vars_by_name = get_reform_master_and_vars()
    ColGen.setup_reformulation!(reform, ClA.ColGenPhase3())
    @test ClMP.getcurcost(master, vars_by_name["x1"]) == 3
    @test ClMP.getcurcost(master, vars_by_name["x2"]) == 4
    @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
    @test ClMP.iscuractive(master, vars_by_name["z"])
end
register!(unit_tests, "colgen_phase", setup_reformulation_colgen_test)

function test_gap()
    mlp_db_sense_closed = [
        # min sense
        (250, 10, true, false),
        (250, 255, true, true),
        (250.1, 250.1, true, true),
        (250.11111, 250.111110, true, true),
        # max sense
        (250, 10, false, true),
        (250, 255, false, false),
        (250.1, 250.1, false, true),
        (250.11111, 250.111112, false, true)
    ]
    for (mlp, db, sense, closed) in mlp_db_sense_closed
        coeff = sense ? 1 : -1 # minimization
        @test ClA._colgen_gap_closed(coeff * mlp, coeff * db, 0.001, 0.001) == closed
    end
end
register!(unit_tests, "colgen_phase", test_gap)

function stop_colgen_phase_if_colgen_converged_eq()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        false,
        99.9998,
        99.9999,
        0,
        false,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_colgen_converged_eq)

function stop_colgen_phase_if_colgen_converged_min()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true, # min sense
        99.9998, # mlp
        100.12, # greater than mlp means colgen has converged
        0,
        false,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_colgen_converged_min)

function stop_colgen_phase_if_colgen_converged_max()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        false, # max sense
        99.9998, # mlp
        99.9, # lower than mlp means colgen has converged
        0,
        false,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_colgen_converged_max)

function stop_colgen_phase_if_iterations_limit()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration(max_nb_iterations = 8))
    colgen_iteration = 8
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        65.87759,
        29.869,
        6,
        false,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_iterations_limit)

function stop_colgen_phase_if_time_limit()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        65.87759,
        29.869,
        6,
        false,
        false,
        false,
        false,
        false,
        true,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_time_limit)

function stop_colgen_phase_if_subproblem_infeasible()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        87859,
        890,
        1,
        false,
        false,
        false,
        true,
        false,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_subproblem_infeasible)

function stop_colgen_phase_if_subproblem_unbounded()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        87859,
        890,
        1,
        false,
        false,
        false,
        false,
        true,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_subproblem_unbounded)

function stop_colgen_phase_if_master_unbounded()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        87859,
        890,
        1,
        false,
        false,
        true,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )

    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_master_unbounded)

function stop_colgen_phase_if_no_new_column()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        87859,
        890,
        0,
        false,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_no_new_column)

function stop_colgen_phase_if_new_cut_in_master()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        87859,
        890,
        1,
        true,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase3(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_new_cut_in_master)

function continue_colgen_phase_otherwise()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    cutsep_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        87859,
        890,
        1,
        false,
        false,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )
    @test !ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iteration, cutsep_iteration)
end
register!(unit_tests, "colgen_phase", continue_colgen_phase_otherwise)


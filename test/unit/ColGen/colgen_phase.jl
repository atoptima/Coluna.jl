
struct TestColGenOutput <: ColGen.AbstractColGenPhaseOutput
    has_art_vars::Bool
    new_cuts_in_master::Bool
    exact_stage::Bool
    has_converged::Bool
end
ClA.colgen_master_has_new_cuts(ctx::TestColGenOutput) = ctx.new_cuts_in_master
ClA.colgen_mast_lp_sol_has_art_vars(ctx::TestColGenOutput) = ctx.has_art_vars
ClA.colgen_uses_exact_stage(ctx::TestColGenOutput) = ctx.exact_stage
ClA.colgen_has_converged(ctx::TestColGenOutput) = ctx.has_converged

# The two following tests are pretty straightforward.
# They are just here to make sure nobody changes the behavior of the phases.
function initial_phase_colgen_test()
    it = ClA.ColunaColGenPhaseIterator()
    @test ColGen.initial_phase(it) isa ClA.ColGenPhase0
end
register!(unit_tests, "colgen_phase", initial_phase_colgen_test)

function next_phase_colgen_test()
    # Classic case where we use exact phase and the algorithm has converged.
    it = ClA.ColunaColGenPhaseIterator()

    table = [
    # Current phase      | art vars | new cut | exact stage | converged | next expected phase | err   | err_type
    ( ClA.ColGenPhase1() , false    , false   , false       , false     , ClA.ColGenPhase2()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , false   , false       , true      , ClA.ColGenPhase2()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , false   , true        , false     , ClA.ColGenPhase2()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , false   , true        , true      , ClA.ColGenPhase2()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , true    , false       , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , true    , false       , true      , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , true    , true        , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , false    , true    , true        , true      , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , true     , false   , false       , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , true     , false   , false       , true      , ClA.ColGenPhase1()  , false , nothing  ), # converging with heuristic pricing means nothing
    ( ClA.ColGenPhase1() , true     , false   , true        , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , true     , false   , true        , true      , nothing             , false , nothing  ), # infeasible
    ( ClA.ColGenPhase1() , true     , true    , false       , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , true     , true    , false       , true      , ClA.ColGenPhase1()  , false , nothing  ), # infeasible 
    ( ClA.ColGenPhase1() , true     , true    , true        , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase1() , true     , true    , true        , true      , nothing             , false , nothing  ), # infeasible
    # Current phase      | art vars | new cut | exact stage | converged | next expected phase | err   | err_type
    ( ClA.ColGenPhase2() , false    , false   , false       , false     , ClA.ColGenPhase2()  , false , nothing  ),
    ( ClA.ColGenPhase2() , false    , false   , false       , true      , ClA.ColGenPhase2()  , false , nothing  ),  # converging with heuristic pricing means nothing
    ( ClA.ColGenPhase2() , false    , false   , true        , false     , ClA.ColGenPhase2()  , false , nothing  ), 
    ( ClA.ColGenPhase2() , false    , false   , true        , true      , nothing             , false , nothing  ), # end of the column generation algorithm
    ( ClA.ColGenPhase2() , false    , true    , false       , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase2() , false    , true    , false       , true      , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase2() , false    , true    , true        , false     , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase2() , false    , true    , true        , true      , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase2() , true     , false   , false       , false     , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , false   , false       , true      , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , false   , true        , false     , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , false   , true        , true      , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , true    , false       , false     , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , true    , false       , true      , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , true    , true        , false     , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    ( ClA.ColGenPhase2() , true     , true    , true        , true      , nothing             , true  , ClA.UnexpectedEndOfColGenPhase ), # no artificial vars in phase 2 of colgen
    # Current phase      | art vars | new cut | exact stage | converged | next expected phase | err   | err_type
    ( ClA.ColGenPhase0() , false    , false   , false       , false     , ClA.ColGenPhase0()  , false , nothing  ), # you should have converged but you may have hit another limit
    ( ClA.ColGenPhase0() , false    , false   , false       , true      , ClA.ColGenPhase0()  , false , nothing  ), # converging with heuristic pricing means nothing
    ( ClA.ColGenPhase0() , false    , false   , true        , false     , ClA.ColGenPhase0()  , false , nothing  ), # you should have converged but you may have hit another limit
    ( ClA.ColGenPhase0() , false    , false   , true        , true      , nothing             , false , nothing  ), # end of the column generation algorithm
    ( ClA.ColGenPhase0() , false    , true    , false       , false     , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , false    , true    , false       , true      , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , false    , true    , true        , false     , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , false    , true    , true        , true      , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , true     , false   , false       , false     , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , true     , false   , false       , true      , ClA.ColGenPhase0()  , false , nothing  ), # converging with heuristic pricing means nothing
    ( ClA.ColGenPhase0() , true     , false   , true        , false     , ClA.ColGenPhase1()  , false , nothing  ), # you should have converged but you may have hit another limit. Let's try phase 1.
    ( ClA.ColGenPhase0() , true     , false   , true        , true      , ClA.ColGenPhase1()  , false , nothing  ),
    ( ClA.ColGenPhase0() , true     , true    , false       , false     , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , true     , true    , false       , true      , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , true     , true    , true        , false     , ClA.ColGenPhase0()  , false , nothing  ),
    ( ClA.ColGenPhase0() , true     , true    , true        , true      , ClA.ColGenPhase0()  , false , nothing  ),
    ]

    # Current phase      | art vars | n dew cut | exact stage | converged | next expected phase | err   | err_type
    for (cp, art, cut, exact, conv, exp, err, err_type) in table
        if !err
            @test ColGen.next_phase(it, cp, TestColGenOutput(art, cut, exact, conv)) isa typeof(exp)
        else
            @test_throws err_type ColGen.next_phase(it, cp, TestColGenOutput(art, cut, exact, conv))
        end
    end
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
    ColGen.setup_reformulation!(reform, ClA.ColGenPhase0())
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
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        false,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_colgen_converged_eq)

function stop_colgen_phase_if_colgen_converged_min()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true, # min sense
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_colgen_converged_min)

function stop_colgen_phase_if_colgen_converged_max()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        false, # max sense
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_colgen_converged_max)

function stop_colgen_phase_if_iterations_limit()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration(max_nb_iterations = 8))
    colgen_iteration = 8
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_iterations_limit)

function stop_colgen_phase_if_time_limit()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_time_limit)

function stop_colgen_phase_if_subproblem_infeasible()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_subproblem_infeasible)

function stop_colgen_phase_if_subproblem_unbounded()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_subproblem_unbounded)

function stop_colgen_phase_if_master_unbounded()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_master_unbounded)

function stop_colgen_phase_if_no_new_column()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_no_new_column)

function stop_colgen_phase_if_new_cut_in_master()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase0(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", stop_colgen_phase_if_new_cut_in_master)

function continue_colgen_phase_otherwise()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test !ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration)
end
register!(unit_tests, "colgen_phase", continue_colgen_phase_otherwise)

function stop_when_inf_db()
    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())
    colgen_iteration = 1
    env = nothing

    colgen_iter_output = ClA.ColGenIterationOutput(
        true,
        Inf,
        4578,
        Inf,
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
    ip_primal_sol = Coluna.Algorithm.GlobalPrimalBoundHandler(reform)
    @test ColGen.stop_colgen_phase(ctx, ClA.ColGenPhase1(), env, colgen_iter_output, colgen_iter_output.db, ip_primal_sol, colgen_iteration) 
end
register!(unit_tests, "colgen_phase", stop_when_inf_db)

function infeasible_phase_output()

    reform, _, _ = get_reform_master_and_vars()
    ctx = ClA.ColGenContext(reform, ClA.ColumnGeneration())

    colgen_phase_output = ClA.ColGenPhaseOutput(
        nothing,
        nothing,
        nothing,
        nothing,
        167673.9643, #mlp
        162469.0291, #db
        false,
        true,
        true, #infeasible
        true, #exact_stage
        false,
        6,
        true
    )

    @test ColGen.stop_colgen(ctx, colgen_phase_output)

    colgen_output = ColGen.new_output(ClA.ColGenOutput, colgen_phase_output)

    @test colgen_output.infeasible == true
    @test isnothing(colgen_output.master_lp_primal_sol)
    @test isnothing(colgen_output.master_ip_primal_sol)
    @test isnothing(colgen_output.master_lp_dual_sol)
    @test_broken isnothing(colgen_output.mlp)
    @test_broken isnothing(colgen_output.db)

    master = ClA.getmaster(reform)
    optstate = ClA._colgen_optstate_output(colgen_output, master)

    @test optstate.termination_status == ClA.INFEASIBLE

end
register!(unit_tests, "colgen_phase", infeasible_phase_output)
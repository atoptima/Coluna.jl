ClMP.getuid(i::Int) = i # hack avoid creating formulations for the tests.

function test_colgen_stage_iterator()
    nb_optimizers_per_pricing_prob = Dict(1 => 3, 2 => 2, 3 => 4)
    it = Coluna.Algorithm.ColGenStageIterator(nb_optimizers_per_pricing_prob)

    stage = ColGen.initial_stage(it)
    @test ColGen.stage_id(stage) == 4
    @test !ColGen.is_exact_stage(stage)
    @test ColGen.get_pricing_subprob_optimizer(stage, 1) == 3
    @test ColGen.get_pricing_subprob_optimizer(stage, 2) == 2
    @test ColGen.get_pricing_subprob_optimizer(stage, 3) == 4

    stage = ColGen.decrease_stage(it, stage)
    @test ColGen.stage_id(stage) == 3
    @test !ColGen.is_exact_stage(stage)
    @test ColGen.get_pricing_subprob_optimizer(stage, 1) == 2
    @test ColGen.get_pricing_subprob_optimizer(stage, 2) == 1
    @test ColGen.get_pricing_subprob_optimizer(stage, 3) == 3

    stage = ColGen.decrease_stage(it, stage)
    @test ColGen.stage_id(stage) == 2
    @test !ColGen.is_exact_stage(stage)
    @test ColGen.get_pricing_subprob_optimizer(stage, 1) == 1
    @test ColGen.get_pricing_subprob_optimizer(stage, 2) == 1
    @test ColGen.get_pricing_subprob_optimizer(stage, 3) == 2

    stage = ColGen.decrease_stage(it, stage)
    @test ColGen.stage_id(stage) == 1
    @test ColGen.is_exact_stage(stage)
    @test ColGen.get_pricing_subprob_optimizer(stage, 1) == 1
    @test ColGen.get_pricing_subprob_optimizer(stage, 2) == 1
    @test ColGen.get_pricing_subprob_optimizer(stage, 3) == 1

    stage = ColGen.decrease_stage(it, stage)
    @test isnothing(stage)
end
register!(unit_tests, "colgen_stage", test_colgen_stage_iterator)

struct TestStageColGenPhaseOutput <: ColGen.AbstractColGenPhaseOutput
    new_cuts_in_master::Bool
    no_new_cols::Bool
    has_converged::Bool
end

ClA.colgen_master_has_new_cuts(output::TestStageColGenPhaseOutput) = output.new_cuts_in_master
ClA.colgen_has_no_new_cols(output::TestStageColGenPhaseOutput) = output.no_new_cols
ClA.colgen_has_converged(output::TestStageColGenPhaseOutput) = output.has_converged

function test_colgen_next_stage()
    nb_optimizers_per_pricing_prob = Dict(1 => 3, 2 => 2, 3 => 4)
    it = Coluna.Algorithm.ColGenStageIterator(nb_optimizers_per_pricing_prob)

    # ColGen.next_stage always returns the same stage, the next in the decreasing sequence,
    # or the initial stage.

    cur_stage = ColGen.initial_stage(it) # 4
    heur_stage = ColGen.decrease_stage(it, cur_stage) # 3
    cur_stage = ColGen.decrease_stage(it, heur_stage) # 2
    exact_stage = ColGen.decrease_stage(it, cur_stage) # 1
    @test ColGen.stage_id(heur_stage) == 3
    @test !ColGen.is_exact_stage(heur_stage)
    @test ColGen.stage_id(exact_stage) == 1
    @test ColGen.is_exact_stage(exact_stage)

    table = [
    # stage_id | new cut | no more col| conv  | next stage
    ( 3        , false   , false      , false , 3          ), # other limit
    ( 3        , false   , false      , true  , 3          ), # impossible in theory
    ( 3        , false   , true       , false , 2          ),
    ( 3        , false   , true       , true  , 3          ),
    ( 3        , true    , false      , false , 4          ),
    ( 3        , true    , false      , true  , 4          ), # impossible in theory
    ( 3        , true    , true       , false , 4          ),
    ( 3        , true    , true       , true  , 4          ),
    # stage_id | new cut | no more col| conv  | next stage
    ( 1        , false   , false      , false , 1          ), # other limit
    ( 1        , false   , false      , true  , 1          ), # impossible in theory
    ( 1        , false   , true       , false , nothing    ),
    ( 1        , false   , true       , true  , 1          ),
    ( 1        , true    , false      , false , 4          ),
    ( 1        , true    , false      , true  , 4          ), # impossible in theory
    ( 1        , true    , true       , false , 4          ),
    ( 1        , true    , true       , true  , 4          ),
    ]

    for (cur_st_id, cut, no_more_col, conv, next_st_id) in table
        stage = cur_st_id == 3 ? heur_stage : exact_stage
        next_stage = ColGen.next_stage(it, stage, TestStageColGenPhaseOutput(cut, no_more_col, conv))

        if isnothing(next_st_id)
            @test isnothing(next_stage)
        else
            @test ColGen.stage_id(next_stage) == next_st_id
        end
    end
end
register!(unit_tests, "colgen_stage", test_colgen_next_stage)
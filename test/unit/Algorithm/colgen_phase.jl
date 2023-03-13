
struct TestColGenContext
    has_art_vars 
end
ClA.colgen_mast_lp_sol_has_art_vars(ctx::TestColGenContext) = ctx.has_art_vars

@testset "Algorithm - colgen" begin
    # These tests are pretty straightforward.
    # They are just here to make sure nobody changes the behavior of the phases.
    @testset "phases" begin
        it = ClA.ColunaColGenPhaseIterator()
        @test ClA.initial_phase(it) isa ClA.ColGenPhase3
        @test ClA.next_phase(it, ClA.ColGenPhase3(), TestColGenContext(true)) isa ClA.ColGenPhase1
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase3(), TestColGenContext(false)))
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase1(), TestColGenContext(true)))
        @test ClA.next_phase(it, ClA.ColGenPhase1(), TestColGenContext(false)) isa ClA.ColGenPhase2
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase2(), TestColGenContext(true)))
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase2(), TestColGenContext(false)))
    end
end

struct TestColGenContext <: ClA.AbstractColGenContext
    has_art_vars 
end
ClA.colgen_mast_lp_sol_has_art_vars(ctx::TestColGenContext) = ctx.has_art_vars

@testset "Algorithm - colgen" begin
    # These tests are pretty straightforward.
    # They are just here to make sure nobody changes the behavior of the phases.
    @testset "initial_phase" begin
        it = ClA.ColunaColGenPhaseIterator()
    end

    @testset "next_phase" begin
        @test ClA.next_phase(it, ClA.ColGenPhase3(), TestColGenContext(true)) isa ClA.ColGenPhase1
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase3(), TestColGenContext(false)))
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase1(), TestColGenContext(true)))
        @test ClA.next_phase(it, ClA.ColGenPhase1(), TestColGenContext(false)) isa ClA.ColGenPhase2
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase2(), TestColGenContext(true)))
        @test isnothing(ClA.next_phase(it, ClA.ColGenPhase2(), TestColGenContext(false)))
    end

    @testset "setup_reformulation" begin
        
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

        reform, master, vars_by_name = get_reform_master_and_vars()

        @test ClMP.getcurcost(master, vars_by_name["x1"]) == 3
        @test ClMP.getcurcost(master, vars_by_name["x2"]) == 4
        @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
        @test ClMP.iscuractive(master, vars_by_name["z"])

        ClA.setup_reformulation!(reform, ClA.ColGenPhase1())
        @test ClMP.getcurcost(master, vars_by_name["x1"]) == 0
        @test ClMP.getcurcost(master, vars_by_name["x2"]) == 0
        @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
        @test ClMP.iscuractive(master, vars_by_name["z"])

        reform, master, vars_by_name = get_reform_master_and_vars()
        ClA.setup_reformulation!(reform, ClA.ColGenPhase2())
        @test ClMP.getcurcost(master, vars_by_name["x1"]) == 3
        @test ClMP.getcurcost(master, vars_by_name["x2"]) == 4
        @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
        @test !ClMP.iscuractive(master, vars_by_name["z"])

        reform, master, vars_by_name = get_reform_master_and_vars()
        ClA.setup_reformulation!(reform, ClA.ColGenPhase3())
        @test ClMP.getcurcost(master, vars_by_name["x1"]) == 3
        @test ClMP.getcurcost(master, vars_by_name["x2"]) == 4
        @test ClMP.getcurcost(master, vars_by_name["z"]) == 1000
        @test ClMP.iscuractive(master, vars_by_name["z"])
    end
end
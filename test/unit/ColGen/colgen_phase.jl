
struct TestColGenContext <: ColGen.AbstractColGenContext
    has_art_vars 
end
ClA.colgen_mast_lp_sol_has_art_vars(ctx::TestColGenContext) = ctx.has_art_vars


# The two following tests are pretty straightforward.
# They are just here to make sure nobody changes the behavior of the phases.
function initial_phase_colgen_test()
    it = ClA.ColunaColGenPhaseIterator()
    @test ColGen.initial_phase(it) isa ClA.ColGenPhase3
end
register!(unit_tests, "colgen_phase", initial_phase_colgen_test)

function next_phase_colgen_test()
    it = ClA.ColunaColGenPhaseIterator()
    @test ColGen.next_phase(it, ClA.ColGenPhase3(), TestColGenContext(true)) isa ClA.ColGenPhase1
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase3(), TestColGenContext(false)))
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase1(), TestColGenContext(true)))
    @test ColGen.next_phase(it, ClA.ColGenPhase1(), TestColGenContext(false)) isa ClA.ColGenPhase2
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase2(), TestColGenContext(true)))
    @test isnothing(ColGen.next_phase(it, ClA.ColGenPhase2(), TestColGenContext(false)))
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


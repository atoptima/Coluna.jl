
function printer_colgen_iteration_master_ok_pricing_ok()
    output = Coluna.Algorithm.ColGenIterationOutput(
        true,
        22.5,
        22.5 - 23/4,
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
    expected_str = "  <st= 9> <it=  1> <et= 2.34> <mst= 1.23> <sp= 0.12> <cols= 1> <al= 0.12> <DB=   16.7500> <mlp=   22.5000> <PB=Inf>"
    str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 9, 0.12, 1.23, 2.34, 0.12, Inf)
    @test expected_str == str
end
register!(unit_tests, "colgen_printer", printer_colgen_iteration_master_ok_pricing_ok)

function printer_colgen_iteration_master_infeasible()
    output = Coluna.Algorithm.ColGenIterationOutput(
        true,
        nothing,
        Inf,
        0,
        false,
        true,
        false,
        false,
        false,
        false,
        nothing,
        nothing,
        nothing
    )
    expected_str = "  <st= 9> <it=  1> <et= 2.34> - infeasible master"
    str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 9, 0.12, 1.23, 2.34, 0.0, Inf)
    @test expected_str == str
end
register!(unit_tests, "colgen_printer", printer_colgen_iteration_master_infeasible)

function printer_colgen_iteration_pricing_infeasible()
    output = Coluna.Algorithm.ColGenIterationOutput(
        true,
        nothing,
        Inf,
        0,
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
    expected_str = "  <st= 9> <it=  1> <et= 2.34> - infeasible subproblem"
    str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 9, 0.12, 1.23, 2.34, 0.0, Inf)
    @test expected_str == str
end
register!(unit_tests, "colgen_printer", printer_colgen_iteration_pricing_infeasible)

function printer_colgen_iteration_master_unbounded()
    output = Coluna.Algorithm.ColGenIterationOutput(
        true,
        nothing,
        -Inf,
        0,
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
    expected_str = ""
    str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 9, 0.12, 1.23, 2.34, 0.0, Inf)
    @test_broken expected_str == str
end
register!(unit_tests, "colgen_printer", printer_colgen_iteration_master_unbounded)

function printer_colgen_iteration_pricing_unbounded()
    output = Coluna.Algorithm.ColGenIterationOutput(
        true,
        nothing,
        nothing,
        0,
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
    expected_str = "  <st= 9> <it=  1> <et= 2.34> - unbounded subproblem"
    str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 9, 0.12, 1.23, 2.34, 0.0, Inf)
    @test expected_str == str
end
register!(unit_tests, "colgen_printer", printer_colgen_iteration_pricing_unbounded)

# function printer_colgen_finds_ip_primal_sol()
#     output = Coluna.Algorithm.ColGenIterationOutput(
#         true,
#         22.5,
#         22.5 - 23/4,
#         1,
#         false,
#         false,
#         false,
#         false,
#         false,
#         false,
#         nothing,
#         [7.0, 7.0, 7.0]
#     )
#     expected_str = ""
#     str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 0.12, 1.23, 2.34)
#     @show str
#     @test_broken expected_str == str
# end
# register!(unit_tests, "colgen_printer", printer_colgen_finds_ip_primal_sol)

function printer_colgen_new_cuts_in_master()
    output = Coluna.Algorithm.ColGenIterationOutput(
        true,
        nothing,
        nothing,
        0,
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
    expected_str = "  <st= 9> <it=  1> <et= 2.34> - new essential cut in master"
    str = Coluna.Algorithm._colgen_iter_str(1, output, 3, 9, 0.12, 1.23, 2.34, 0.0, Inf)
    @test expected_str == str
end
register!(unit_tests, "colgen_printer", printer_colgen_new_cuts_in_master)

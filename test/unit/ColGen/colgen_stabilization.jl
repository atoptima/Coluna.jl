# Test the implementation of the stabilization procedure.

# Make sure the value of α is updated correctly after each misprice.
# The goal is to tend to 0.0 after a given number of misprices.
function test_misprice_schedule()
    smooth_factor = 1
    nb_misprices = 0
    α = 0.8
    for i in 1:10
        α = Coluna.Algorithm._misprice_schedule(smooth_factor, nb_misprices, α)
        nb_misprices += 1
        @show α
    end
    return
end
register!(unit_tests, "colgen_stabilization", test_misprice_schedule; f = true)

function test_primal_solution()
    
end
register!(unit_tests, "colgen_stabilization", test_primal_solution; f = true)

# Make sure the angle is well computed.
function test_angle()

end
register!(unit_tests, "colgen_stabilization", test_angle; f = true)

function test_dynamic_alpha_schedule()

end
register!(unit_tests, "colgen_stabilization", test_dynamic_alpha_schedule; f = true)

# Mock implementation of the column generation to make sure the stabilization logic works
# as expected.

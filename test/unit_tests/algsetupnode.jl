function algsetupnode_unit_tests()

    variable_small_info_tests()
    variable_info_tests()
    # sb_var_info_tests()

end

function variable_small_info_tests()
    vars = create_array_of_vars(1, CL.Variable)
    var = vars[1]

    vsi = CL.VariableSmallInfo(var)
    @test vsi.variable == var
    @test vsi.cost == var.cur_cost_rhs
    @test vsi.status == CL.Active

    vsi = CL.VariableSmallInfo(var, CL.Unsuitable)
    @test vsi.variable == var
    @test vsi.cost == var.cur_cost_rhs
    @test vsi.status == CL.Unsuitable
end

function variable_info_tests()
    vars = create_array_of_vars(1, CL.Variable)
    var = vars[1]

    vinfo = CL.VariableInfo(var)
    @test vinfo.variable == var
    @test vinfo.lb == var.cur_lb
    @test vinfo.ub == var.cur_ub
    @test vinfo.status == CL.Active

    vinfo = CL.VariableInfo(var, CL.Inactive)
    @test vinfo.variable == var
    @test vinfo.lb == var.cur_lb
    @test vinfo.ub == var.cur_ub
    @test vinfo.status == CL.Inactive
end

# function sb_var_info_tests()
#     vars = create_array_of_vars(1, CL.SubprobVar)
#     var = vars[1]
#     vinfo = CL.SpVariableInfo(var, CL.Unsuitable)
#     @test vinfo.variable == var
#     @test vinfo.lb == var.cur_lb
#     @test vinfo.ub == var.cur_ub
#     @test vinfo.local_lb == var.local_lb
#     @test vinfo.local_ub == var.local_ub
#     @test vinfo.status == CL.Unsuitable
# end

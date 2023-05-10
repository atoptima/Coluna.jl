function parser_strip_indentation()
    s = "1.1*x_1"
    @test Parser._strip_identation(s) == "1.1*x_1"
    s = " 1.1*x_1"
    @test Parser._strip_identation(s) == "1.1*x_1"
    s = "   1.1*x_1"
    @test Parser._strip_identation(s) == "1.1*x_1"
end
register!(unit_tests, "parser", parser_strip_indentation)

function parser_strip_line()
    s = "1.1*x_1,2.2*y_1,3.3*z_1"
    @test Parser._strip_line(s) == "1.1*x_1,2.2*y_1,3.3*z_1"
    s = "   1.1*x_1, 2.2*y_1,    3.3*z_1   "
    @test Parser._strip_line(s) == "1.1*x_1,2.2*y_1,3.3*z_1"
    s = "   1.1*x_1 , 2.2*y_1 , 3.3*z_1   "
    @test Parser._strip_line(s) == "1.1*x_1,2.2*y_1,3.3*z_1"
end
register!(unit_tests, "parser", parser_strip_line)

function parser_get_vars_list()
    s = "x_1,y_1,z_1"
    @test Parser._get_vars_list(s) == ["x_1", "y_1", "z_1"]
    s = "   x_1, y_1,    z_1   "
    @test Parser._get_vars_list(s) == ["x_1", "y_1", "z_1"]
    s = "   x_1 , y_1 , z_1   "
    @test Parser._get_vars_list(s) == ["x_1", "y_1", "z_1"]
end
register!(unit_tests, "parser", parser_get_vars_list)

function parser_read_expression()
    s = "x_1 + y_1 - z_1"
    @test Parser._read_expression(s).vars == Dict("y_1" => 1.0, "x_1" => 1.0, "z_1" => -1.0)
    s = "- x_1 + 2.5*y_1 - 3z_1"
    @test Parser._read_expression(s).vars == Dict("y_1" => 2.5, "x_1" => -1.0, "z_1" => -3.0)
    s = "2*x_1 + 6*y_1 - 1.1z_1"
    @test Parser._read_expression(s).vars == Dict("y_1" => 6.0, "x_1" => 2.0, "z_1" => -1.1)
end
register!(unit_tests, "parser", parser_read_expression)

function parser_read_constraint()
    s = "=="
    @test Parser._read_constraint(s) === nothing
    s = "x_1 + y_1"
    @test Parser._read_constraint(s) === nothing
    s = "x_1 + y_1 <="
    @test Parser._read_constraint(s) === nothing
    s = "x_1 + y_1 >= z_1"
    @test Parser._read_constraint(s) === nothing
    s = "x_1 + 1.2y_1 == 5"
    c = Parser._read_constraint(s)
    @test c.lhs.vars == Dict("y_1" => 1.2, "x_1" => 1.0)
    @test c.sense == ClMP.Equal
    @test c.rhs == 5.0
    s = "-4x_1 + 1.2*y_1 <= 5"
    c = Parser._read_constraint(s)
    @test c.lhs.vars == Dict("y_1" => 1.2, "x_1" => -4.0)
    @test c.sense == ClMP.Less
    @test c.rhs == 5.0
    s = "-4.25*x_1 + 2y_1 >= 5"
    c = Parser._read_constraint(s)
    @test c.lhs.vars == Dict("y_1" => 2.0, "x_1" => -4.25)
    @test c.sense == ClMP.Greater
    @test c.rhs == 5.0
end
register!(unit_tests, "parser", parser_read_constraint)

function parser_read_bounds()
    less_r = Regex("(($(Parser.coeff_re))<=)?([\\w,]+)(<=($(Parser.coeff_re)))?")
    greater_r = Regex("(($(Parser.coeff_re))>=)?([\\w,]+)(>=($(Parser.coeff_re)))?")
    s = ""
    @test Parser._read_bounds(s, less_r) == ([], "", "")
    s = "y == 10"
    @test Parser._read_bounds(s, less_r) == (["y"], "", "")
    @test Parser._read_bounds(s, greater_r) == (["y"], "", "")
    s = "20 <= x"
    @test Parser._read_bounds(s, less_r) == (["x"], "20", "")
    s = "20 <= x <= 21.5"
    @test Parser._read_bounds(s, less_r) == (["x"], "20", "21.5")
    s = "20 <= x1, x2 <= 21.5"
    @test Parser._read_bounds(s, less_r) == (["x1", "x2"], "20", "21.5")
    s = "21.5 >= x"
    @test Parser._read_bounds(s, greater_r) == (["x"], "21.5", "")
    s = "21.5 >= x >= 20"
    @test Parser._read_bounds(s, greater_r) == (["x"], "21.5", "20")
    s = "21.5 >= x1, x2 >= 20"
    @test Parser._read_bounds(s, greater_r) == (["x1", "x2"], "21.5", "20")
end
register!(unit_tests, "parser", parser_read_bounds)
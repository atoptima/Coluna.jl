
@testset "Unit - parser" begin

    @testset "Strip identation" begin
        s = "1.1*x_1"
        @test CL._strip_identation(s) == "1.1*x_1"
        s = " 1.1*x_1"
        @test CL._strip_identation(s) == "1.1*x_1"
        s = "   1.1*x_1"
        @test CL._strip_identation(s) == "1.1*x_1"
    end

    @testset "Strip line" begin
        s = "1.1*x_1,2.2*y_1,3.3*z_1"
        @test CL._strip_line(s) == "1.1*x_1,2.2*y_1,3.3*z_1"
        s = "   1.1*x_1, 2.2*y_1,    3.3*z_1   "
        @test CL._strip_line(s) == "1.1*x_1,2.2*y_1,3.3*z_1"
        s = "   1.1*x_1 , 2.2*y_1 , 3.3*z_1   "
        @test CL._strip_line(s) == "1.1*x_1,2.2*y_1,3.3*z_1"
    end

    @testset "Get vars list" begin
        s = "x_1,y_1,z_1"
        @test CL._get_vars_list(s) == ["x_1", "y_1", "z_1"]
        s = "   x_1, y_1,    z_1   "
        @test CL._get_vars_list(s) == ["x_1", "y_1", "z_1"]
        s = "   x_1 , y_1 , z_1   "
        @test CL._get_vars_list(s) == ["x_1", "y_1", "z_1"]
    end

    @testset "Read expression" begin
        s = "x_1 + y_1 - z_1"
        @test CL._read_expression(s).vars == Dict("y_1" => 1.0, "x_1" => 1.0, "z_1" => -1.0)
        s = "- x_1 + 2.5*y_1 - 3z_1"
        @test CL._read_expression(s).vars == Dict("y_1" => 2.5, "x_1" => -1.0, "z_1" => -3.0)
        s = "2*x_1 + 6*y_1 - 1.1z_1"
        @test CL._read_expression(s).vars == Dict("y_1" => 6.0, "x_1" => 2.0, "z_1" => -1.1)
    end

    @testset "Read constraint" begin
        s = "=="
        @test CL._read_constraint(s) === nothing
        s = "x_1 + y_1"
        @test CL._read_constraint(s) === nothing
        s = "x_1 + y_1 <="
        @test CL._read_constraint(s) === nothing
        s = "x_1 + y_1 >= z_1"
        @test CL._read_constraint(s) === nothing
        s = "x_1 + 1.2y_1 == 5"
        c = CL._read_constraint(s)
        @test c.lhs.vars == Dict("y_1" => 1.2, "x_1" => 1.0)
        @test c.sense == ClMP.Equal
        @test c.rhs == 5.0
        s = "-4x_1 + 1.2*y_1 <= 5"
        c = CL._read_constraint(s)
        @test c.lhs.vars == Dict("y_1" => 1.2, "x_1" => -4.0)
        @test c.sense == ClMP.Less
        @test c.rhs == 5.0
        s = "-4.25*x_1 + 2y_1 >= 5"
        c = CL._read_constraint(s)
        @test c.lhs.vars == Dict("y_1" => 2.0, "x_1" => -4.25)
        @test c.sense == ClMP.Greater
        @test c.rhs == 5.0
    end

    @testset "Read bounds" begin
        less_r = Regex("(($(CL.coeff_re))<=)?([\\w,]+)(<=($(CL.coeff_re)))?")
        greater_r = Regex("(($(CL.coeff_re))>=)?([\\w,]+)(>=($(CL.coeff_re)))?")
        s = ""
        @test CL._read_bounds(s, less_r) == ([], "", "")
        s = "y == 10"
        @test CL._read_bounds(s, less_r) == (["y"], "", "")
        @test CL._read_bounds(s, greater_r) == (["y"], "", "")
        s = "20 <= x"
        @test CL._read_bounds(s, less_r) == (["x"], "20", "")
        s = "20 <= x <= 21.5"
        @test CL._read_bounds(s, less_r) == (["x"], "20", "21.5")
        s = "20 <= x1, x2 <= 21.5"
        @test CL._read_bounds(s, less_r) == (["x1", "x2"], "20", "21.5")
        s = "21.5 >= x"
        @test CL._read_bounds(s, greater_r) == (["x"], "21.5", "")
        s = "21.5 >= x >= 20"
        @test CL._read_bounds(s, greater_r) == (["x"], "21.5", "20")
        s = "21.5 >= x1, x2 >= 20"
        @test CL._read_bounds(s, greater_r) == (["x1", "x2"], "21.5", "20")
    end

end

function types_unit_tests()
    types_builders_and_helpers_tests()
end

function types_builders_and_helpers_tests()

    @test CL.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.EqualTo}(-1)
    @test CL.MoiConstrIndex() == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(-1)
    @test CL.MoiVarIndex() == MOI.VariableIndex(-1)
    @test CL.MoiVarKind() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.Integer}(-1)
    @test CL.getsense(MOI.LessThan{Float64}(0.0)) == CL.Less
    @test CL.getsense(MOI.GreaterThan{Float64}(0.0)) == CL.Greater
    @test CL.getsense(MOI.EqualTo{Float64}(0.0)) == CL.Equal
    @test CL.getrhs(MOI.LessThan{Float64}(-12.3)) == -12.3
    @test CL.getrhs(MOI.GreaterThan{Float64}(-12.3)) == -12.3
    @test CL.getrhs(MOI.EqualTo{Float64}(-12.3)) == -12.3
    @test CL.getkind(MOI.ZeroOne()) == CL.Binary
    @test CL.getkind(MOI.Integer()) == CL.Integ
    @test CL.get_moi_set(CL.Less) == MOI.LessThan
    @test CL.get_moi_set(CL.Greater) == MOI.GreaterThan
    @test CL.get_moi_set(CL.Equal) == MOI.EqualTo

end

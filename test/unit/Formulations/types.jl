function types_unit_tests()
    types_builders_and_helpers_tests()
end

function types_builders_and_helpers_tests()

    @test ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.EqualTo}(-1)
    @test ClF.MoiConstrIndex() == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(-1)
    @test ClF.MoiVarIndex() == MOI.VariableIndex(-1)
    @test ClF.MoiVarKind() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.Integer}(-1)
    @test ClF.getsense(MOI.LessThan{Float64}(0.0)) == ClF.Less
    @test ClF.getsense(MOI.GreaterThan{Float64}(0.0)) == ClF.Greater
    @test ClF.getsense(MOI.EqualTo{Float64}(0.0)) == ClF.Equal
    @test ClF.getrhs(MOI.LessThan{Float64}(-12.3)) == -12.3
    @test ClF.getrhs(MOI.GreaterThan{Float64}(-12.3)) == -12.3
    @test ClF.getrhs(MOI.EqualTo{Float64}(-12.3)) == -12.3
    @test ClF.getkind(MOI.ZeroOne()) == ClF.Binary
    @test ClF.getkind(MOI.Integer()) == ClF.Integ
    @test ClF.get_moi_set(ClF.Less) == MOI.LessThan
    @test ClF.get_moi_set(ClF.Greater) == MOI.GreaterThan
    @test ClF.get_moi_set(ClF.Equal) == MOI.EqualTo

end

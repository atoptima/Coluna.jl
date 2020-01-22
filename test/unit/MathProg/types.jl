function types_unit_tests()
    types_builders_and_helpers_tests()
end

function types_builders_and_helpers_tests()
    @test ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.EqualTo}(-1)
    @test ClF.MoiConstrIndex() == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(-1)
    @test ClF.MoiVarIndex() == MOI.VariableIndex(-1)
    @test ClF.MoiVarKind() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.Integer}(-1)
    @test ClF.convert_moi_sense_to_coluna(MOI.LessThan{Float64}(0.0)) == ClF.Less
    @test ClF.convert_moi_sense_to_coluna(MOI.GreaterThan{Float64}(0.0)) == ClF.Greater
    @test ClF.convert_moi_sense_to_coluna(MOI.EqualTo{Float64}(0.0)) == ClF.Equal
    @test ClF.convert_moi_rhs_to_coluna(MOI.LessThan{Float64}(-12.3)) == -12.3
    @test ClF.convert_moi_rhs_to_coluna(MOI.GreaterThan{Float64}(-12.3)) == -12.3
    @test ClF.convert_moi_rhs_to_coluna(MOI.EqualTo{Float64}(-12.3)) == -12.3
    @test ClF.convert_moi_kind_to_coluna(MOI.ZeroOne()) == ClF.Binary
    @test ClF.convert_moi_kind_to_coluna(MOI.Integer()) == ClF.Integ
    @test ClF.convert_coluna_sense_to_moi(ClF.Less) == MOI.LessThan
    @test ClF.convert_coluna_sense_to_moi(ClF.Greater) == MOI.GreaterThan
    @test ClF.convert_coluna_sense_to_moi(ClF.Equal) == MOI.EqualTo
    return
end

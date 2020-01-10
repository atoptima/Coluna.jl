function types_unit_tests()
    types_builders_and_helpers_tests()
end

function types_builders_and_helpers_tests()
    @test ClF.MoiConstrIndex{MOI.SingleVariable,MOI.EqualTo}() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.EqualTo}(-1)
    @test ClF.MoiConstrIndex() == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(-1)
    @test ClF.MoiVarIndex() == MOI.VariableIndex(-1)
    @test ClF.MoiVarKind() == MOI.ConstraintIndex{MOI.SingleVariable,MOI.Integer}(-1)
    @test ClF.tr_sense_MOI_to_Coluna(MOI.LessThan{Float64}(0.0)) == ClF.Less
    @test ClF.tr_sense_MOI_to_Coluna(MOI.GreaterThan{Float64}(0.0)) == ClF.Greater
    @test ClF.tr_sense_MOI_to_Coluna(MOI.EqualTo{Float64}(0.0)) == ClF.Equal
    @test ClF.tr_rhs_MOI_to_Coluna(MOI.LessThan{Float64}(-12.3)) == -12.3
    @test ClF.tr_rhs_MOI_to_Coluna(MOI.GreaterThan{Float64}(-12.3)) == -12.3
    @test ClF.tr_rhs_MOI_to_Coluna(MOI.EqualTo{Float64}(-12.3)) == -12.3
    @test ClF.tr_kind_MOI_to_Coluna(MOI.ZeroOne()) == ClF.Binary
    @test ClF.tr_kind_MOI_to_Coluna(MOI.Integer()) == ClF.Integ
    @test ClF.tr_sense_Coluna_to_MOI(ClF.Less) == MOI.LessThan
    @test ClF.tr_sense_Coluna_to_MOI(ClF.Greater) == MOI.GreaterThan
    @test ClF.tr_sense_Coluna_to_MOI(ClF.Equal) == MOI.EqualTo
    return
end

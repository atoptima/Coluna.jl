@testset "MathProg - type builders & helpers" begin
    @test ClMP.MoiConstrIndex{MOI.VariableIndex,MOI.EqualTo}() == MOI.ConstraintIndex{MOI.VariableIndex,MOI.EqualTo}(-1)
    @test ClMP.MoiConstrIndex() == MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},MOI.LessThan{Float64}}(-1)
    @test ClMP.MoiVarIndex() == MOI.VariableIndex(-1)
    @test ClMP.MoiVarKind() == MOI.ConstraintIndex{MOI.VariableIndex,MOI.Integer}(-1)

    @test ClMP.convert_moi_sense_to_coluna(MOI.LessThan{Float64}(0.0)) == ClMP.Less
    @test ClMP.convert_moi_sense_to_coluna(MOI.GreaterThan{Float64}(0.0)) == ClMP.Greater
    @test ClMP.convert_moi_sense_to_coluna(MOI.EqualTo{Float64}(0.0)) == ClMP.Equal

    @test ClMP.convert_moi_rhs_to_coluna(MOI.LessThan{Float64}(-12.3)) == -12.3
    @test ClMP.convert_moi_rhs_to_coluna(MOI.GreaterThan{Float64}(-12.3)) == -12.3
    @test ClMP.convert_moi_rhs_to_coluna(MOI.EqualTo{Float64}(-12.3)) == -12.3

    @test ClMP.convert_moi_bounds_to_coluna(MOI.LessThan{Float64}(3.0)) == (-Inf, 3.0)
    @test ClMP.convert_moi_bounds_to_coluna(MOI.GreaterThan{Float64}(4.0)) == (4.0, Inf)
    @test ClMP.convert_moi_bounds_to_coluna(MOI.EqualTo{Float64}(5.0)) == (5.0, 5.0)
    @test ClMP.convert_moi_bounds_to_coluna(MOI.Interval{Float64}(1.0, 2.0)) == (1.0, 2.0)

    @test ClMP.convert_moi_kind_to_coluna(MOI.ZeroOne()) == ClMP.Binary
    @test ClMP.convert_moi_kind_to_coluna(MOI.Integer()) == ClMP.Integ

    @test ClMP.convert_coluna_sense_to_moi(ClMP.Less) == MOI.LessThan{Float64}
    @test ClMP.convert_coluna_sense_to_moi(ClMP.Greater) == MOI.GreaterThan{Float64}
    @test ClMP.convert_coluna_sense_to_moi(ClMP.Equal) == MOI.EqualTo{Float64}
    return
end
